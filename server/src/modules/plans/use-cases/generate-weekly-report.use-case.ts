import { logger } from '@shared/logger/logger';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { CoachRuntimeContextService } from '@modules/coach/use-cases/coach-runtime-context.service';
import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { PlanRepository } from '../domain/plan.repository';
import { Plan, PlanWeek } from '../domain/plan.entity';
import {
  WeeklyReport,
  WeeklyReportMetrics,
} from '../domain/weekly-report.entity';
import { WeeklyReportRepository } from '../domain/weekly-report.repository';
import { NotFoundError } from '@shared/errors/app-error';

export class GenerateWeeklyReportUseCase {
  private runtime = new CoachRuntimeContextService();
  private llm = getAsyncLLM();

  constructor(
    private readonly plans: PlanRepository,
    private readonly runs: RunRepository,
    private readonly reports: WeeklyReportRepository,
  ) {}

  /**
   * Returns existing ready report (idempotent) or kicks off async generation.
   * On idempotent hit: returns the existing ready report.
   * On miss: creates pending doc + spawns background generation, returns pending.
   */
  async execute(
    userId: string,
    planId: string,
    weekNumber: number,
  ): Promise<WeeklyReport> {
    const plan = await this.plans.findById(planId, userId);
    if (!plan || plan.userId !== userId) {
      throw new NotFoundError('Plan');
    }
    const week = plan.weeks.find((w) => w.weekNumber === weekNumber);
    if (!week) {
      throw new NotFoundError(`Plan week ${weekNumber}`);
    }

    const existing = await this.reports.findByWeek(planId, weekNumber, userId);
    if (existing && existing.status === 'ready') return existing;

    const now = new Date().toISOString();
    const { weekStart, weekEnd } = computeWeekWindow(plan, weekNumber);

    const pending: WeeklyReport = {
      id: String(weekNumber),
      planId,
      userId,
      weekNumber,
      weekStart: weekStart.toISOString(),
      weekEnd: weekEnd.toISOString(),
      metrics: emptyMetrics(week),
      runIds: [],
      summary: '',
      coachHighlights: [],
      status: 'pending',
      generatedAt: now,
      createdAt: existing?.createdAt ?? now,
    };
    await this.reports.save(pending);

    this._generateAsync(plan, week, weekStart, weekEnd).catch((err) => {
      logger.error('weekly-report.generate.background_failed', {
        planId,
        weekNumber,
        err: err instanceof Error ? err.message : String(err),
      });
      this.reports
        .update(planId, weekNumber, userId, { status: 'failed' })
        .catch(() => {});
    });

    return pending;
  }

  private async _generateAsync(
    plan: Plan,
    week: PlanWeek,
    weekStart: Date,
    weekEnd: Date,
  ): Promise<void> {
    const runs = await this.runs.findByDateRange(plan.userId, weekStart, weekEnd);
    const metrics = computeMetrics(week, runs);

    const runtime = await this.runtime.getContext(plan.userId);
    const knowledge = await formatRunningKnowledgeContext(
      `relatório semanal ${plan.goal} ${plan.level} semana ${week.weekNumber}`,
      3,
    );

    const prompt = buildWeeklyReportPrompt({
      plan,
      week,
      metrics,
      runs,
      profileName: runtime.profile?.name ?? 'corredor',
      knowledge,
    });

    const raw = await this.llm.generate(prompt, {
      systemPrompt:
        'Você é um coach de corrida brasileiro. Escreva análises semanais curtas, diretas e em Português.',
      maxTokens: 600,
      temperature: 0.7,
    });

    const { summary, coachHighlights } = parseResponse(raw);

    await this.reports.update(plan.id, week.weekNumber, plan.userId, {
      metrics,
      runIds: runs.map((r) => r.id),
      summary,
      coachHighlights,
      status: 'ready',
      generatedAt: new Date().toISOString(),
    });

    logger.info('weekly-report.generate.completed', {
      planId: plan.id,
      weekNumber: week.weekNumber,
      runs: runs.length,
    });
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

function computeWeekWindow(plan: Plan, weekNumber: number): { weekStart: Date; weekEnd: Date } {
  const planStart = new Date(plan.createdAt);
  const weekStart = new Date(
    Date.UTC(planStart.getUTCFullYear(), planStart.getUTCMonth(), planStart.getUTCDate()),
  );
  weekStart.setUTCDate(weekStart.getUTCDate() + (weekNumber - 1) * 7);
  const weekEnd = new Date(weekStart);
  weekEnd.setUTCDate(weekEnd.getUTCDate() + 6);
  weekEnd.setUTCHours(23, 59, 59, 999);
  return { weekStart, weekEnd };
}

function emptyMetrics(week: PlanWeek): WeeklyReportMetrics {
  const plannedDistanceKm = week.sessions.reduce((s, x) => s + (x.distanceKm ?? 0), 0);
  return {
    plannedSessions: week.sessions.length,
    completedRuns: 0,
    plannedDistanceKm,
    actualDistanceKm: 0,
    completionRate: 0,
    totalDurationS: 0,
  };
}

function computeMetrics(week: PlanWeek, runs: Run[]): WeeklyReportMetrics {
  const plannedDistanceKm = week.sessions.reduce((s, x) => s + (x.distanceKm ?? 0), 0);
  const actualDistanceM = runs.reduce((s, r) => s + (r.distanceM ?? 0), 0);
  const actualDistanceKm = actualDistanceM / 1000;
  const totalDurationS = runs.reduce((s, r) => s + (r.durationS ?? 0), 0);

  const bpms = runs.map((r) => r.avgBpm).filter((b): b is number => typeof b === 'number');
  const avgBpm = bpms.length > 0 ? Math.round(bpms.reduce((s, b) => s + b, 0) / bpms.length) : undefined;
  const maxBpm = bpms.length > 0 ? Math.max(...bpms) : undefined;

  const paces = runs
    .map((r) => r.avgPace)
    .filter((p): p is string => typeof p === 'string' && /^\d+:\d{2}$/.test(p));
  const avgPaceStr = paces.length > 0 ? averagePace(paces) : undefined;

  const plannedSessions = week.sessions.length;
  const completedRuns = runs.length;
  const completionRate = plannedSessions === 0 ? 0 : Math.min(1, completedRuns / plannedSessions);

  return {
    plannedSessions,
    completedRuns,
    plannedDistanceKm,
    actualDistanceKm: Math.round(actualDistanceKm * 10) / 10,
    completionRate: Math.round(completionRate * 100) / 100,
    avgBpm,
    maxBpm,
    avgPaceStr,
    totalDurationS,
  };
}

function averagePace(paces: string[]): string {
  const seconds = paces.map((p) => {
    const [m, s] = p.split(':').map(Number);
    return m * 60 + s;
  });
  const avg = Math.round(seconds.reduce((s, x) => s + x, 0) / seconds.length);
  const m = Math.floor(avg / 60);
  const s = avg % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function buildWeeklyReportPrompt(args: {
  plan: Plan;
  week: PlanWeek;
  metrics: WeeklyReportMetrics;
  runs: Run[];
  profileName: string;
  knowledge: string;
}): string {
  const { plan, week, metrics, runs, profileName, knowledge } = args;
  const sessionsPlanned = week.sessions
    .map((s) => `  - dia ${s.dayOfWeek}: ${s.type} ${s.distanceKm}km${s.targetPace ? ` @ ${s.targetPace}` : ''}`)
    .join('\n');
  const runsActual = runs.length === 0
    ? '  (nenhuma corrida registrada)'
    : runs
        .map(
          (r) =>
            `  - ${r.createdAt.slice(0, 10)}: ${(r.distanceM / 1000).toFixed(1)}km, ${formatDuration(r.durationS)}, pace ${r.avgPace ?? '—'}, bpm ${r.avgBpm ?? '—'}`,
        )
        .join('\n');

  return `# RELATÓRIO SEMANAL — Plano ${plan.goal} (${plan.level})

## Foco da semana ${week.weekNumber}
${week.focus ?? '(sem foco definido)'} — ${week.narrative ?? ''}

## Sessões planejadas
${sessionsPlanned}

## Corridas registradas (${runs.length}/${week.sessions.length})
${runsActual}

## Métricas agregadas
- Distância planejada: ${metrics.plannedDistanceKm.toFixed(1)} km
- Distância real: ${metrics.actualDistanceKm.toFixed(1)} km
- Taxa de aderência: ${Math.round(metrics.completionRate * 100)}%
- BPM médio: ${metrics.avgBpm ?? '—'}
- Pace médio: ${metrics.avgPaceStr ?? '—'}/km
- Duração total: ${formatDuration(metrics.totalDurationS)}

## Conhecimento base
${knowledge}

## Instruções
Escreva uma análise semanal para ${profileName} em **Português brasileiro**, com **150-200 palavras**. Tom direto e empático, foco em:
1. O que correu bem
2. O que ficou abaixo do planejado (se aplicável)
3. Como ajustar a próxima semana

Depois da análise, liste **2 a 3 highlights** começando cada um com "- " (hífen + espaço), curtos (1 frase cada). Esse bloco virá depois de uma linha com "---".

Formato de resposta:
[análise 150-200 palavras]
---
- [highlight 1]
- [highlight 2]
- [highlight 3 opcional]`;
}

function parseResponse(raw: string): { summary: string; coachHighlights: string[] } {
  const cleaned = raw.trim();
  const parts = cleaned.split(/\n-{3,}\n/);
  const summary = parts[0]?.trim() ?? cleaned;
  const highlightsRaw = parts[1] ?? '';
  const coachHighlights = highlightsRaw
    .split('\n')
    .map((line) => line.replace(/^[-*•]\s*/, '').trim())
    .filter((line) => line.length > 0)
    .slice(0, 3);
  return { summary, coachHighlights };
}

function formatDuration(s: number): string {
  if (s <= 0) return '0m';
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  return h > 0 ? `${h}h${m}m` : `${m}m`;
}
