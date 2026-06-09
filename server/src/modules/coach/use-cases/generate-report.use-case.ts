import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import {
  buildPostRunReportPrompt,
  buildPostRunReportEnrichedPrompt,
} from '@shared/infra/llm/prompts';
import { CoachReport, CoachReportSections } from '../domain/coach-report.entity';
import { CoachReportRepository } from '../domain/coach-report.repository';
import { CoachRuntimeContextService } from './coach-runtime-context.service';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Plan, PlanRevision, PlanSession, effectivePlanWeeks } from '@modules/plans/domain/plan.entity';

/**
 * Geração two-phase do relatório pós-corrida:
 *   Fase A (summary_ready): texto curto ~30s (UX rápida)
 *   Fase B (enriched): 4 seções estruturadas via JSON, lendo plano +
 *     última revisão (do checkpoint semanal) pra contexto rico
 *
 * UI ([report_page.dart]) renderiza por status:
 *   pending      → skeleton
 *   summary_ready→ card único com `summary`
 *   enriched     → 4 cards expansíveis com `sections`
 *   ready (legacy) → equivale a summary_ready (compat com reports antigos)
 *
 * Fase B é fire-and-forget — falha não trava a fase A (já gravada).
 */
export class GenerateReportUseCase {
  private llm = getAsyncLLM();
  private runtime = new CoachRuntimeContextService();

  constructor(
    private readonly reports: CoachReportRepository,
    private readonly runs: RunRepository,
  ) {}

  async execute(run: Run, userId: string): Promise<string> {
    const dist = (run.distanceM / 1000).toFixed(2);
    const minutes = Math.floor(run.durationS / 60);

    // Short-circuit: corrida < 500m é teste ou cancelada. LLM gera lixo
    // ("essa corrida de 0.01km mostra...") porque não tem dado pra analisar.
    // Salvar texto fixo, não chamar LLM. Pula fase B (sem dado pra enriquecer).
    if (run.distanceM < 500) {
      const summary =
        'Corrida muito curta pra análise. Quando rolar uma sessão de 1km+ eu te mando um relatório completo com pace, esforço e recomendação pra próxima.';
      await this.reports.save({
        runId: run.id,
        userId,
        summary,
        status: 'summary_ready',
        generatedAt: new Date().toISOString(),
      });
      await this.runs.update(run.id, userId, { coachReportId: run.id });
      logger.info('coach.report.skipped_short_run', {
        runId: run.id,
        distanceM: run.distanceM,
      });
      return run.id;
    }

    const runtime = await this.runtime.getContext(userId);

    const knowledgeContext = await formatRunningKnowledgeContext(
      `${run.type} corrida ${dist}km pace ${run.avgPace ?? ''} bpm ${run.avgBpm ?? ''}`,
      3,
    );

    const summaryLines = [
      `- Tipo: ${run.type}`,
      `- Distância: ${dist}km`,
      `- Duração: ${minutes} minutos`,
      `- Pace médio: ${run.avgPace ?? 'N/A'}/km`,
      `- BPM médio: ${run.avgBpm ?? 'N/A'}`,
      `- BPM máximo: ${run.maxBpm ?? 'N/A'}`,
    ];
    if (run.targetPace) summaryLines.push(`- Pace alvo: ${run.targetPace}/km`);

    // Comparativo META vs FEITO da sessão planejada. Sem essas linhas,
    // o coach gerava o relatório sem saber se o user cumpriu/passou/
    // ficou abaixo do plano — análises ficavam genéricas. Free Run
    // (planSessionId == null) pula esse bloco.
    if (run.planSessionId) {
      try {
        const fullPlan = await this._fetchCurrentPlan(userId);
        const planned = fullPlan
          ? _findPlannedSession(fullPlan, run.planSessionId)
          : null;
        if (planned) {
          summaryLines.push('- META vs FEITO da sessão planejada:');
          summaryLines.push(
            `  · Distância: planejado ${planned.distanceKm.toFixed(1)}km, feito ${dist}km`,
          );
          if (planned.targetPace) {
            summaryLines.push(
              `  · Pace: planejado ${planned.targetPace}/km, feito ${run.avgPace ?? 'N/A'}/km`,
            );
          }
          if (planned.durationMin != null) {
            summaryLines.push(
              `  · Duração: planejado ${Math.round(planned.durationMin)}min, feito ${minutes}min`,
            );
          }
        }
      } catch (err) {
        logger.warn('coach.report.planned_compare_failed', {
          runId: run.id,
          err: String(err),
        });
      }
    }

    const planContext = runtime.currentPlan
      ? `Plano: ${runtime.currentPlan.goal} (${runtime.currentPlan.level}, semana atual ${runtime.currentPlan.currentWeek?.weekNumber ?? 'N/A'})`
      : 'Sem plano ativo.';

    const recentRunsContext = runtime.recentRuns
      .slice(0, 5)
      .map(r => `${r.type} ${r.distanceKm}km em ${r.durationMin}min`)
      .join('; ') || 'Sem corridas recentes.';

    const built = await buildPostRunReportPrompt({
      profile: runtime.profile,
      run: { summary: summaryLines.join('\n') },
      planContext,
      recentRunsContext,
      ragContext: knowledgeContext,
    });

    try {
      const summary = await this.llm.generate(built.userPrompt, {
        systemPrompt: built.systemPrompt,
        maxTokens: built.maxTokens,
        temperature: built.temperature,
        userId,
        useCase: 'run-report',
      });
      const reportId = run.id;

      await this.reports.save({
        runId: reportId,
        userId,
        summary,
        status: 'summary_ready',
        generatedAt: new Date().toISOString(),
      });

      await this.runs.update(run.id, userId, { coachReportId: reportId });

      logger.info('coach.report.summary_ready', { runId: run.id, version: built.version, source: built.source });

      // Fase B em background — fire-and-forget. UI vai dar polling até
      // status=enriched. Se falhar, summary fica disponível indefinidamente.
      this._enrichInBackground(run, userId, summary, summaryLines.join('\n')).catch(err => {
        logger.warn('coach.report.enrich_failed_background', { runId: run.id, err: String(err) });
      });

      return reportId;
    } catch (err) {
      logger.error('coach.report.failed', { runId: run.id, err });
      throw err;
    }
  }

  /**
   * Fase B: gera as 4 seções estruturadas usando plano + revisões já
   * registradas (não há mais ajuste por corrida — a revisão mais recente
   * vem do checkpoint semanal de domingo). Busca 10 últimas runs +
   * última revisão pra ancorar o prompt com input rico.
   */
  private async _enrichInBackground(
    run: Run,
    userId: string,
    legacySummary: string,
    runSummary: string,
  ): Promise<void> {
    try {
      const [runtime, plan, recentResult] = await Promise.all([
        this.runtime.getContext(userId),
        this._fetchCurrentPlan(userId),
        this.runs.findByUser(userId, 10),
      ]);
      const recentRuns = recentResult.runs;

      const planContextEnriched = this._buildEnrichedPlanContext(plan);
      const planAdaptResult = this._buildPlanAdaptResult(plan, run.completedAt ?? run.createdAt);
      const recentRunsContext = recentRuns
        .filter(r => r.status === 'completed')
        .slice(0, 10)
        .map(r => {
          const km = (r.distanceM / 1000).toFixed(1);
          const min = Math.round(r.durationS / 60);
          return `${r.type} ${km}km em ${min}min pace ${r.avgPace ?? 'N/A'} bpm ${r.avgBpm ?? 'N/A'}`;
        })
        .join('; ') || 'Sem corridas anteriores.';

      const knowledgeContext = await formatRunningKnowledgeContext(
        `${run.type} corrida análise evolução plano ${runtime.profile?.goal ?? ''} ${runtime.profile?.level ?? ''}`,
        4,
      );

      const built = await buildPostRunReportEnrichedPrompt({
        profile: runtime.profile,
        run: { summary: runSummary },
        planContext: planContextEnriched,
        planAdaptResult,
        recentRunsContext,
        ragContext: knowledgeContext,
      });

      const raw = await this.llm.generate(built.userPrompt, {
        systemPrompt: built.systemPrompt,
        maxTokens: built.maxTokens,
        temperature: built.temperature,
        userId,
        useCase: 'run-report-enriched',
      });

      const sections = this._parseEnrichedJson(raw);
      if (!sections) {
        logger.warn('coach.report.enrich_parse_failed', { runId: run.id, rawLen: raw.length });
        return;
      }

      // Merge: mantém summary anterior e adiciona sections + status atualizado.
      const enrichedReport: CoachReport = {
        runId: run.id,
        userId,
        summary: legacySummary,
        status: 'enriched',
        generatedAt: new Date().toISOString(),
        sections,
        enrichedAt: new Date().toISOString(),
      };
      await this.reports.save(enrichedReport);

      logger.info('coach.report.enriched', {
        runId: run.id,
        version: built.version,
        source: built.source,
        sectionsLen: {
          runAnalysis: sections.runAnalysis.length,
          planEvolution: sections.planEvolution.length,
          nextSessions: sections.nextSessions.length,
          recommendations: sections.recommendations.length,
        },
      });

      // Notifica user (in-app + push) que o relatório completo está
      // pronto. Summary já está visível direto na tela; a push aqui é
      // pra trazer o user de volta quando o coach termina as 4 seções.
      // Dynamic import pra evitar circular dep com container.
      void this._notifyReportEnriched(userId, run.id).catch((err: unknown) =>
        logger.warn('coach.report.notify_failed', {
          runId: run.id,
          err: err instanceof Error ? err.message : String(err),
        }),
      );
    } catch (err) {
      logger.warn('coach.report.enrich_inner_failed', { runId: run.id, err: String(err) });
    }
  }

  /**
   * Notifica usuário (in-app + push) que o relatório enriquecido está
   * pronto pra leitura. Idempotente via dedupeKey=runId.
   */
  private async _notifyReportEnriched(userId: string, runId: string): Promise<void> {
    const { container } = await import('@shared/container');
    const route = `/history/run/${runId}`;
    await container.useCases.createNotification.execute({
      userId,
      type: 'coach_message',
      dedupeKey: `report_enriched_${runId}`,
      title: 'COACH FECHOU SUA CORRIDA',
      icon: 'chat_bubble_outline',
      body: 'Relatório completo da última corrida pronto: análise, próximas sessões e recomendações.',
      ctaLabel: 'VER RELATORIO',
      ctaRoute: route,
    });
    await container.useCases.sendUserPush.execute(userId, {
      title: 'Coach terminou sua análise',
      body: 'Toque pra ver o relatório completo da última corrida.',
      data: { kind: 'coach_report_ready', route, runId },
    });
  }

  private async _fetchCurrentPlan(userId: string): Promise<Plan | null> {
    try {
      const snap = await getFirestore()
        .collection(`users/${userId}/plans`)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();
      if (snap.empty) return null;
      const doc = snap.docs[0];
      if (!doc) return null;
      return { id: doc.id, userId, ...doc.data() } as Plan;
    } catch {
      return null;
    }
  }

  /** Plano com semana anterior, atual e próxima — recortado pra caber
   *  no prompt sem inflar 200 sessões inteiras. Usa o snapshot VIGENTE
   *  (adjustedWeeks) pra o relatório refletir o plano que o atleta tá
   *  realmente seguindo, não a base imutável. */
  private _buildEnrichedPlanContext(plan: Plan | null): string {
    const weeks = plan ? effectivePlanWeeks(plan) : [];
    if (!plan || plan.status !== 'ready' || weeks.length === 0) {
      return 'Sem plano ativo.';
    }
    const createdAt = Date.parse(plan.createdAt);
    const idx = Number.isNaN(createdAt)
      ? 0
      : Math.min(
          Math.floor((Date.now() - createdAt) / (7 * 86_400_000)),
          weeks.length - 1,
        );
    const slice = [
      weeks[idx - 1],
      weeks[idx],
      weeks[idx + 1],
    ].filter((w): w is NonNullable<typeof w> => !!w);
    const lines = [
      `Plano: ${plan.goal} (${plan.level}, ${plan.weeksCount} semanas)`,
      `Semana atual: ${idx + 1}/${plan.weeksCount}`,
      '',
      ...slice.map(w => {
        const sessionsTxt = w.sessions
          .map(s => `${s.type} ${s.distanceKm}km${s.targetPace ? ` @ ${s.targetPace}` : ''}`)
          .join(' / ');
        return `Semana ${w.weekNumber} (${w.focus ?? 'sem foco'}): ${sessionsTxt}`;
      }),
    ];
    return lines.join('\n');
  }

  /** Última revisão automática registrada após a corrida em questão. */
  private _buildPlanAdaptResult(plan: Plan | null, runCompletedAt: string): string {
    if (!plan?.revisions || plan.revisions.length === 0) return '';
    const runTs = Date.parse(runCompletedAt);
    if (Number.isNaN(runTs)) return '';
    const recent: PlanRevision[] = plan.revisions
      .filter(r => Date.parse(r.revisedAt) >= runTs - 1000)
      .sort((a, b) => Date.parse(b.revisedAt) - Date.parse(a.revisedAt));
    const latest = recent[0];
    if (!latest) return '';
    const change = latest.changes
      ? ` (sessões ajustadas: ${latest.changes.sessionsAdjusted ?? 0}, volume delta: ${latest.changes.volumeDelta ?? 0}km, intensidade: ${latest.changes.intensityShift ?? 'unchanged'})`
      : '';
    return `Revisão automática semana ${latest.weekNumber}: ${latest.summary}${change}`;
  }

  /**
   * Parser defensivo: LLM pode entregar JSON puro, com fence ```json,
   * ou com texto antes/depois. Extrai o primeiro objeto válido com
   * as 4 chaves esperadas.
   */
  private _parseEnrichedJson(raw: string): CoachReportSections | null {
    const cleaned = raw
      .replace(/```json\s*/gi, '')
      .replace(/```\s*$/g, '')
      .trim();
    const firstBrace = cleaned.indexOf('{');
    const lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace === -1 || lastBrace === -1 || lastBrace < firstBrace) return null;
    const jsonStr = cleaned.slice(firstBrace, lastBrace + 1);
    try {
      const parsed = JSON.parse(jsonStr) as Partial<CoachReportSections>;
      if (
        typeof parsed.runAnalysis === 'string' &&
        typeof parsed.planEvolution === 'string' &&
        typeof parsed.nextSessions === 'string' &&
        typeof parsed.recommendations === 'string'
      ) {
        return {
          runAnalysis: parsed.runAnalysis.trim(),
          planEvolution: parsed.planEvolution.trim(),
          nextSessions: parsed.nextSessions.trim(),
          recommendations: parsed.recommendations.trim(),
        };
      }
      return null;
    } catch {
      return null;
    }
  }
}

/** Lookup linear da PlanSession por id em todas as semanas.
 *  Olha primeiro o vigente; cai pra base se a revisão removeu a sessão
 *  mas a run histórica ainda aponta pra ela. */
function _findPlannedSession(plan: Plan, sessionId: string): PlanSession | null {
  for (const week of effectivePlanWeeks(plan)) {
    const s = week.sessions.find((s) => s.id === sessionId);
    if (s) return s;
  }
  if (plan.adjustedWeeks && plan.adjustedWeeks.length > 0) {
    for (const week of plan.weeks) {
      const s = week.sessions.find((s) => s.id === sessionId);
      if (s) return s;
    }
  }
  return null;
}
