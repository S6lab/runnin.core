import { RunRepository } from '@modules/runs/domain/run.repository';
import { logger } from '@shared/logger/logger';
import { CoachReportRepository } from '../domain/coach-report.repository';
import { CoachReport } from '../domain/coach-report.entity';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { createHash } from 'crypto';

export interface PeriodAnalysisRun {
  id: string;
  distanceM: number;
  durationS: number;
  avgPace?: string;
  avgBpm?: number;
  maxBpm?: number;
  type: string;
  date: string;
}

export interface PeriodAnalysis {
  userId: string;
  runs: PeriodAnalysisRun[];
  summary: string;
  status: 'ready';
  generatedAt: string;
  /** Indica origem do summary — útil pra admin auditar quando o cache pegou. */
  source?: 'cache' | 'reports' | 'fallback';
}

/**
 * Sintetiza o período a partir dos `coachReports/{runId}` já gerados — SEM
 * call LLM. Cada run já teve `summary` + `sections` produzidos pelo
 * `GenerateReportUseCase` no momento do completeRun. Aqui só agregamos.
 *
 * Cache por hash dos runIds: se chega o mesmo conjunto de runs, devolve
 * cached. Quando uma run nova entra, o hash muda e re-sintetiza. Pago o
 * write Firestore 1x por mudança de set; reads de Histórico viram quase
 * gratuitos.
 *
 * Antes: cada navegação no Histórico (mudar filtro, navegar período)
 * disparava 1 call Gemini Flash + RAG retrieval. Heavy user com 7 runs/sem
 * × 3 navs/dia = ~600 calls/mês desnecessárias.
 */
export class GeneratePeriodAnalysisUseCase {
  constructor(
    private readonly runs: RunRepository,
    private readonly reports: CoachReportRepository,
  ) {}

  async execute(userId: string, limit: number = 10, cursor?: string): Promise<PeriodAnalysis> {
    const { runs: periodRuns } = await this.runs.findByUser(userId, limit, cursor);

    if (periodRuns.length === 0) {
      return {
        userId,
        runs: [],
        summary: 'Nenhuma corrida registrada neste período.',
        status: 'ready',
        generatedAt: new Date().toISOString(),
        source: 'fallback',
      };
    }

    // Cache hit: mesmo conjunto de runs => mesmo summary. Quando uma run
    // nova entra, o hash muda e re-sintetiza. Janela de cache é implícita:
    // ela "expira" naturalmente quando o user corre de novo.
    const runIds = periodRuns.map((r) => r.id);
    const cacheKey = this._cacheKey(runIds);
    const cached = await this._readCache(userId, cacheKey);
    if (cached) {
      logger.info('coach.period-analysis.cache_hit', { userId, runCount: runIds.length });
      return { ...cached, source: 'cache' };
    }

    // Busca os reports já gerados (1 batch read). Reports antigos podem
    // não ter `summary` ou `sections` — caímos no fallback determinístico
    // por run sem custo extra.
    const reports = await this.reports.findByRunIds(userId, runIds);
    const reportByRunId = new Map<string, CoachReport>(reports.map((r) => [r.runId, r]));

    const runsData: PeriodAnalysisRun[] = periodRuns.map((r) => ({
      id: r.id,
      distanceM: r.distanceM,
      durationS: r.durationS,
      avgPace: r.avgPace,
      avgBpm: r.avgBpm,
      maxBpm: r.maxBpm,
      type: r.type,
      date: new Date(r.createdAt).toISOString(),
    }));

    const summary = this._buildDeterministicSummary(periodRuns, reportByRunId);
    const source: 'reports' | 'fallback' = reports.length > 0 ? 'reports' : 'fallback';

    const result: PeriodAnalysis = {
      userId,
      runs: runsData,
      summary,
      status: 'ready',
      generatedAt: new Date().toISOString(),
      source,
    };

    // Best-effort cache. Falha silenciosa — leitura subsequente vai
    // recalcular, sem impacto pro user.
    void this._writeCache(userId, cacheKey, result);
    logger.info('coach.period-analysis.generated', {
      userId,
      runCount: runIds.length,
      reportsHit: reports.length,
      source,
    });

    return result;
  }

  /** Hash determinístico do conjunto ordenado de runIds — colisão zero pra
   *  o range que importa (10-30 runs). Curto pra caber em doc id Firestore. */
  private _cacheKey(runIds: string[]): string {
    const sorted = [...runIds].sort().join(',');
    return createHash('sha1').update(sorted).digest('hex').slice(0, 16);
  }

  private async _readCache(userId: string, key: string): Promise<PeriodAnalysis | null> {
    try {
      const snap = await getFirestore()
        .collection(`users/${userId}/period_analysis_cache`)
        .doc(key)
        .get();
      if (!snap.exists) return null;
      const data = snap.data();
      if (!data) return null;
      return data as PeriodAnalysis;
    } catch (err) {
      logger.warn('coach.period-analysis.cache_read_failed', { userId, err: String(err) });
      return null;
    }
  }

  private async _writeCache(userId: string, key: string, payload: PeriodAnalysis): Promise<void> {
    try {
      await getFirestore()
        .collection(`users/${userId}/period_analysis_cache`)
        .doc(key)
        .set(payload);
    } catch (err) {
      logger.warn('coach.period-analysis.cache_write_failed', { userId, err: String(err) });
    }
  }

  /**
   * Síntese determinística do período. Estratégia:
   *  1. Header com totais (corridas, km, duração, BPM).
   *  2. Se >=50% das runs têm reports com `summary`, extrai a frase mais
   *     densa de cada e concatena com transição leve.
   *  3. Fecha com observação sobre consistência/volume relativo.
   */
  private _buildDeterministicSummary(
    runs: { id: string; distanceM: number; durationS: number; avgBpm?: number; maxBpm?: number; createdAt: string }[],
    reportByRunId: Map<string, CoachReport>,
  ): string {
    const totalKm = runs.reduce((s, r) => s + r.distanceM / 1000, 0);
    const totalMin = Math.round(runs.reduce((s, r) => s + r.durationS, 0) / 60);
    const avgBpmValues = runs.map((r) => r.avgBpm).filter((b): b is number => typeof b === 'number');
    const maxBpmValues = runs.map((r) => r.maxBpm).filter((b): b is number => typeof b === 'number');
    const avgBpm = avgBpmValues.length > 0
      ? Math.round(avgBpmValues.reduce((a, b) => a + b, 0) / avgBpmValues.length)
      : null;
    const maxBpm = maxBpmValues.length > 0 ? Math.max(...maxBpmValues) : null;

    const bpmLine = avgBpm
      ? ` BPM médio ${avgBpm}${maxBpm ? `, pico ${maxBpm}` : ''}.`
      : '';

    const header = `Você somou ${runs.length} ${runs.length === 1 ? 'corrida' : 'corridas'} totalizando ${totalKm.toFixed(1)} km em ${totalMin} minutos.${bpmLine}`;

    // Pega trechos curtos dos reports existentes — frase de abertura ou
    // sumário top. Limita a 2-3 pra não inflar.
    const reportSnippets: string[] = [];
    for (const r of runs.slice(0, 3)) {
      const rep = reportByRunId.get(r.id);
      if (!rep) continue;
      const snippet = this._extractInsightSnippet(rep);
      if (snippet) reportSnippets.push(snippet);
    }

    if (reportSnippets.length === 0) {
      // Sem reports (período legado ou muito antigo): observação
      // determinística baseada em volume.
      const closing = this._volumeObservation(runs.length, totalKm);
      return `${header} ${closing}`;
    }

    const insights = reportSnippets.join(' ');
    const closing = this._consistencyObservation(runs.length, totalKm);

    return `${header}\n\nReflexões do coach sobre as corridas recentes: ${insights}\n\n${closing}`;
  }

  /** Pega uma frase útil do report: prioriza `runAnalysis` da fase enriched,
   *  cai pro `summary` da fase A se enriched ainda não rodou. */
  private _extractInsightSnippet(rep: CoachReport): string | null {
    const fromEnriched = rep.sections?.runAnalysis;
    const candidate = (fromEnriched && fromEnriched.trim().length > 0)
      ? fromEnriched
      : rep.summary;
    if (!candidate) return null;
    const cleaned = candidate.trim().replace(/\s+/g, ' ');
    // Primeiras 1-2 frases (~200 chars) — o suficiente pra entregar valor
    // sem inflar o card. Se a fase enriched vier muito densa, capamos.
    const sentences = cleaned.split(/(?<=[.!?])\s+/).slice(0, 2).join(' ');
    return sentences.length > 240 ? sentences.slice(0, 237) + '...' : sentences;
  }

  private _volumeObservation(count: number, totalKm: number): string {
    const avgKm = totalKm / count;
    if (count === 1) return 'Uma única sessão no período — o próximo passo é dar continuidade pra construir consistência.';
    if (avgKm < 4) return 'Volume médio leve — bom pra base e recuperação, mas o pulo de qualidade vem com sessões um pouco mais longas no horizonte.';
    if (avgKm < 8) return 'Volume médio em zona de construção — esse é o intervalo onde a adaptação cardiovascular ganha tração.';
    return 'Volume médio sólido — esse é território de quem está pronto pra introduzir sessões mais específicas (limiar, longão progressivo).';
  }

  private _consistencyObservation(count: number, totalKm: number): string {
    if (count >= 5 && totalKm >= 30) return 'Consistência forte no período: frequência e volume estão alinhados. Próximo destrave é qualidade — tempo run, tiros curtos, longão controlado.';
    if (count >= 3) return 'Boa cadência no período. Mantenha a regularidade — o ganho aeróbico aparece em 3-4 semanas de continuidade.';
    return 'Sequência curta — vale priorizar consistência antes de adicionar intensidade.';
  }
}
