import { BiometricSampleType } from '../domain/biometric-sample.entity';
import { BiometricSampleRepository } from '../domain/biometric-sample.repository';

export interface BiometricSummary {
  windowDays: number;
  from: string;
  to: string;
  // Métricas agregadas (null se sem dados)
  avgRestingBpm: number | null;
  maxBpm: number | null;
  avgSleepHours: number | null;
  /// Score 0-100 de qualidade do sono médio. Composição:
  ///   40 pts duração (target 8h): linear de 0h→0pts, 8h+→40pts
  ///   30 pts %deep (target 13-23% segundo Sleep Foundation): peak no meio
  ///   30 pts %rem (target 20-25%): peak no meio
  /// null se não há stages registradas (só sleep_hours legacy).
  avgSleepQualityScore: number | null;
  /// Médias por estágio em horas (null se sem dados). Permite UI mostrar
  /// breakdown estilo Apple Health.
  avgSleepDeepH: number | null;
  avgSleepRemH: number | null;
  avgSleepLightH: number | null;
  totalSteps: number | null;
  avgHrv: number | null;
  latestWeight: number | null;
  sampleCount: number;
}

/**
 * Computa rollup de N dias por demanda (não usa cache/precompute por enquanto).
 * Custo Firestore: 1 query por user, até 500 docs (limit no repo).
 */
export class GetSummaryUseCase {
  constructor(private readonly repo: BiometricSampleRepository) {}

  async execute(userId: string, windowDays: number = 7): Promise<BiometricSummary> {
    const to = new Date();
    const from = new Date(to.getTime() - windowDays * 24 * 3600 * 1000);

    const samples = await this.repo.findByDateRange(userId, undefined, from, to);

    const byType = (type: BiometricSampleType) => samples.filter((s) => s.type === type);
    const avg = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
    const sum = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) : null);

    const restingBpms = byType('resting_bpm').map((s) => s.value);
    const maxBpms = byType('max_bpm').map((s) => s.value);
    // SLEEP: Apple Watch em iOS 16+ reporta apenas DEEP/REM/LIGHT (sleep_hours
    // pode vir vazio mesmo com user permitindo Sono). Total real é
    // DEEP + REM + LIGHT. Mantemos compat com sleep_hours (apps mais
    // antigos / Android Health Connect) somando ele também — recordedAt
    // diferentes evitam dupla-contagem na prática.
    const sleepHoursRaw = byType('sleep_hours').map((s) => s.value);
    const sleepDeep = byType('sleep_deep').map((s) => s.value);
    const sleepRem = byType('sleep_rem').map((s) => s.value);
    const sleepLight = byType('sleep_light').map((s) => s.value);
    // Sleep médio por DIA, não por sample. Agrupa por dia (YYYY-MM-DD) e
    // soma as horas dentro do dia; depois tira média entre os dias.
    const sleepByDay = new Map<string, number>();
    const addSample = (s: { recordedAt: string; value: number }) => {
      const day = s.recordedAt.substring(0, 10);
      sleepByDay.set(day, (sleepByDay.get(day) ?? 0) + s.value);
    };
    byType('sleep_hours').forEach(addSample);
    byType('sleep_deep').forEach(addSample);
    byType('sleep_rem').forEach(addSample);
    byType('sleep_light').forEach(addSample);
    const sleepDaily = Array.from(sleepByDay.values());
    const steps = byType('steps').map((s) => s.value);
    const hrvs = byType('hrv').map((s) => s.value);
    const weights = byType('weight')
      .sort((a, b) => b.recordedAt.localeCompare(a.recordedAt))
      .map((s) => s.value);

    // Médias por stage e quality score baseado em stages reais. Quando o
    // user tem só sleep_hours (Android antigo ou iOS pré-16), pulamos o
    // score — sem stages dá pra inferir confiança.
    const avgDeepH = sleepDeep.length ? avg(sleepDeep) : null;
    const avgRemH = sleepRem.length ? avg(sleepRem) : null;
    const avgLightH = sleepLight.length ? avg(sleepLight) : null;
    const avgTotal = avg(sleepDaily);
    const qualityScore = computeSleepQualityScore({
      avgTotal,
      avgDeep: avgDeepH,
      avgRem: avgRemH,
    });

    return {
      windowDays,
      from: from.toISOString(),
      to: to.toISOString(),
      avgRestingBpm: avg(restingBpms),
      maxBpm: maxBpms.length ? Math.max(...maxBpms) : null,
      avgSleepHours: avgTotal,
      avgSleepQualityScore: qualityScore,
      avgSleepDeepH: avgDeepH,
      avgSleepRemH: avgRemH,
      avgSleepLightH: avgLightH,
      totalSteps: sum(steps),
      avgHrv: avg(hrvs),
      latestWeight: weights[0] ?? null,
      sampleCount: samples.length,
    };
  }
}

/**
 * Score de qualidade do sono 0-100.
 *   40 pts duração: 0h=0, 8h=40 (capped)
 *   30 pts %deep: ideal 13-23% (peak 18%); penaliza desvio
 *   30 pts %rem: ideal 20-25% (peak 22.5%); penaliza desvio
 * Retorna null se faltam stages (impossível avaliar qualidade só com total).
 */
function computeSleepQualityScore(args: {
  avgTotal: number | null;
  avgDeep: number | null;
  avgRem: number | null;
}): number | null {
  const { avgTotal, avgDeep, avgRem } = args;
  if (!avgTotal || !avgDeep || !avgRem) return null;
  // Duração: linear até 8h, capped.
  const durScore = Math.min(avgTotal / 8, 1) * 40;
  // %deep: ideal 0.18, range OK 0.13-0.23. Fora cai linear até 0.
  const deepPct = avgDeep / avgTotal;
  const deepScore = inIdealRange(deepPct, 0.13, 0.23, 0.18) * 30;
  // %rem: ideal 0.225, range OK 0.20-0.25.
  const remPct = avgRem / avgTotal;
  const remScore = inIdealRange(remPct, 0.2, 0.25, 0.225) * 30;
  return Math.round(durScore + deepScore + remScore);
}

/** Retorna 1.0 no peak, decai linear pros lados, 0 fora do range estendido. */
function inIdealRange(
  value: number,
  rangeMin: number,
  rangeMax: number,
  peak: number,
): number {
  if (value < rangeMin || value > rangeMax) {
    // Fora do range OK — decai metade da distância até a próxima faixa.
    const dist = value < rangeMin ? rangeMin - value : value - rangeMax;
    const tolerance = (rangeMax - rangeMin) * 0.5;
    return Math.max(0, 1 - dist / tolerance) * 0.5; // máx 0.5 fora do OK
  }
  // Dentro do range — decai linear conforme distancia do peak.
  const halfRange = Math.max(peak - rangeMin, rangeMax - peak);
  const dist = Math.abs(value - peak);
  return Math.max(0, 1 - dist / halfRange);
}
