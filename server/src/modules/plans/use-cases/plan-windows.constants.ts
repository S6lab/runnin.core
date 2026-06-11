import { RunnerLevel } from '@modules/users/domain/user.entity';

/**
 * Tabela canônica de janelas (em semanas) por (distância × nível).
 * Cada combinação tem 3 opções: agressivo / factível / seguro.
 *
 * REDIRECT = combinação inviável → server sugere subnível (ex: iniciante
 * pedindo maratona em 14 semanas vira "10K em 12 semanas como Fase 1").
 *
 * Esta tabela é a ÚNICA fonte de verdade — FE renderiza opções, server
 * valida. Manter os dois em sync via copy desta lista pro FE quando
 * mudar.
 *
 * Critério dos números: baseado em literatura de coaching de corrida
 * (Daniels, Pfitzinger). Iniciante = nunca correu / volume <10km/sem.
 * Intermediário = corre regular, 15-30km/sem. Avançado = treina
 * estruturado, >30km/sem.
 */

export type RaceDistanceKm = 5 | 10 | 21 | 42;
export type WindowMode = 'aggressive' | 'feasible' | 'safe';

/** Subgoal pra FLOW (treino sem prova). REDIRECT não se aplica aqui —
 *  todos os subgoals são sempre válidos. */
export type FlowSubgoal = 'start' | 'improve' | 'injury_return' | 'postpartum';

interface WindowEntry {
  /** Semanas pra cada modo, ou null = REDIRECT pra subnível. */
  aggressive: number | null;
  feasible: number | null;
  safe: number;
}

/** Pra cada distância, qual subdistância sugerir quando bloqueia o user. */
export const REDIRECT_TARGET: Record<RaceDistanceKm, RaceDistanceKm | null> = {
  5: null,    // 5K já é menor — não tem pra onde redirecionar
  10: 5,
  21: 10,
  42: 21,
};

export const RACE_WINDOWS: Record<RaceDistanceKm, Record<RunnerLevel, WindowEntry>> = {
  5: {
    iniciante:     { aggressive: 8,  feasible: 10, safe: 12 },
    intermediario: { aggressive: 6,  feasible: 8,  safe: 10 },
    avancado:      { aggressive: 6,  feasible: 6,  safe: 8 },
  },
  10: {
    iniciante:     { aggressive: 10, feasible: 12, safe: 14 },
    intermediario: { aggressive: 8,  feasible: 10, safe: 12 },
    avancado:      { aggressive: 6,  feasible: 8,  safe: 10 },
  },
  21: {
    iniciante:     { aggressive: null, feasible: 16, safe: 20 }, // agressivo REDIRECT→10K
    intermediario: { aggressive: 12,   feasible: 14, safe: 18 },
    avancado:      { aggressive: 10,   feasible: 12, safe: 14 },
  },
  42: {
    iniciante:     { aggressive: null, feasible: null, safe: 26 }, // só seguro permitido
    intermediario: { aggressive: 16,   feasible: 18,   safe: 22 },
    avancado:      { aggressive: 14,   feasible: 16,   safe: 20 },
  },
};

/**
 * Pico de volume semanal (km) mínimo pra terminar a distância com
 * segurança. Plano precisa rampar o currentWeeklyKm até esse alvo dentro
 * da janela escolhida.
 *
 * 5K = 0 (skip check) porque 5K é o ponto de entrada do app — qualquer
 * iniciante consegue via walk-run dentro da janela mínima (8sem). A
 * janela em si já cumpre o papel de gate. Pra 10K+, volume importa.
 *
 * Valores conservadores (literatura: Pfitzinger sugere 50+km/sem pra
 * maratona; nosso "completar" é mais permissivo).
 */
export const PEAK_WEEKLY_KM: Record<RaceDistanceKm, number> = {
  5:  0,   // skip — janela mínima de 8sem já cobre walk-run from zero
  10: 18,
  21: 32,
  42: 45,
};

/** Taxa de crescimento semanal sustentável (regra dos 10%). Usada pelo
 *  volume-validator pra projetar quanto km/sem o atleta consegue rampar
 *  no horizonte do plano. */
export const WEEKLY_RAMP_RATE = 1.10;

/** Base mínima de volume semanal pra iniciar a rampa. Walk-run permite
 *  ~5km/sem desde a primeira semana mesmo pra quem nunca correu
 *  (Couch-to-5K). Sem esse floor, iniciante absoluto fica preso em base=2
 *  e nem 5K cabe. */
export const RAMP_BASE_FLOOR_KM = 5;

/**
 * Subníveis do "iniciante" + intermediario/avancado. O backend só conhece
 * `RunnerLevel` (iniciante|intermediario|avancado), mas o FE refina com
 * `levelHint` (nunca_corri|esporadico|iniciante_freq). Pra calcular regras
 * usamos o "profile" composto. Função `resolveProfileKey()` combina.
 */
export type LevelProfile =
  | 'iniciante_nunca'
  | 'iniciante_esp'
  | 'iniciante_freq'
  | 'intermediario'
  | 'avancado';

export function resolveProfileKey(
  level: RunnerLevel,
  levelHint?: string | null,
): LevelProfile {
  if (level === 'intermediario') return 'intermediario';
  if (level === 'avancado') return 'avancado';
  // level=iniciante: refina por levelHint. Sem hint, assume mais conservador.
  if (levelHint === 'nunca_corri') return 'iniciante_nunca';
  if (levelHint === 'esporadico') return 'iniciante_esp';
  return 'iniciante_freq';
}

/** Sentinel: distância bloqueada pra esse subnível (não importa freq). */
export const BLOCKED_BY_LEVEL = 9999;

/** Matriz mestra de freq mínima por (subnível × distância).
 *  - `BLOCKED_BY_LEVEL` = combinação proibida (bloqueada por LEVEL, não freq).
 *  - Cap de volume/sessão (`MAX_KM_PER_SESSION`) complementa: mesmo
 *    com freq válida, projetado não pode exceder cap do nível. */
export const MIN_FREQ_BY_PROFILE_DISTANCE: Record<LevelProfile, Record<RaceDistanceKm, number>> = {
  iniciante_nunca: { 5: 2, 10: 3, 21: BLOCKED_BY_LEVEL, 42: BLOCKED_BY_LEVEL },
  iniciante_esp:   { 5: 2, 10: 3, 21: BLOCKED_BY_LEVEL, 42: BLOCKED_BY_LEVEL },
  iniciante_freq:  { 5: 2, 10: 3, 21: 4,                42: BLOCKED_BY_LEVEL },
  intermediario:   { 5: 2, 10: 3, 21: 3,                42: 4 },
  avancado:        { 5: 2, 10: 3, 21: 3,                42: 4 },
};

/** Helper: freq mínima pra essa combinação. Retorna BLOCKED_BY_LEVEL pra
 *  combinação bloqueada (caller decide como tratar). */
export function getMinFreqForGoal(
  level: RunnerLevel,
  distance: RaceDistanceKm,
  levelHint?: string | null,
): number {
  const key = resolveProfileKey(level, levelHint);
  return MIN_FREQ_BY_PROFILE_DISTANCE[key][distance];
}

/** Restrições de janela (windowMode permitido) por (subnível × distância).
 *  Sem entrada = sem restrição (todas janelas permitidas). */
export const WINDOW_RESTRICTION_BY_PROFILE: Partial<Record<LevelProfile, Partial<Record<RaceDistanceKm, WindowMode[]>>>> = {
  iniciante_nunca: { 10: ['safe'] },
  iniciante_esp:   { 10: ['safe'] },
};

/** Bypass de improve_pace por nível. Lista de distâncias liberadas
 *  totalmente (qualquer freq, qualquer janela). Iniciante (qualquer
 *  subtipo) NÃO está aqui — sem bypass. */
export const IMPROVE_PACE_BYPASS_BY_LEVEL: Partial<Record<RunnerLevel, RaceDistanceKm[]>> = {
  intermediario: [5, 10],            // só 5K e 10K liberados
  avancado:      [5, 10, 21, 42],    // todas
};

/** Retorna lista de windowModes permitidos pra essa combinação. null = sem
 *  restrição (todas as 3 — agressivo/factível/seguro — permitidas).
 *  Considera matriz estática + regra dinâmica: intermediário + 21K +
 *  freq=3 vira `['safe']` (libera todas quando freq ≥ 4). */
export function getAllowedWindows(
  level: RunnerLevel,
  distance: RaceDistanceKm,
  frequency: number,
  levelHint?: string | null,
): WindowMode[] | null {
  const key = resolveProfileKey(level, levelHint);
  const staticRestriction = WINDOW_RESTRICTION_BY_PROFILE[key]?.[distance];
  if (staticRestriction) return staticRestriction;
  // Dinâmica: intermediário + 21K + freq=3 → só safe. Freq ≥ 4 livre.
  if (key === 'intermediario' && distance === 21 && frequency === 3) {
    return ['safe'];
  }
  return null;
}

/** True se atleta tem bypass de improve_pace pra essa distância. */
export function hasImprovePaceBypass(
  level: RunnerLevel,
  distance: RaceDistanceKm,
): boolean {
  return IMPROVE_PACE_BYPASS_BY_LEVEL[level]?.includes(distance) ?? false;
}

/** Cap de km por sessão por nível. Calculado pelo pico semanal dividido
 *  pela frequência: se passar do cap, plano fica brutal. Iniciante não
 *  faz session >14km nem em pico (long run de 14km é meio-domingo bem
 *  cansativo); avançado tolera long runs até 32km. */
export const MAX_KM_PER_SESSION: Record<RunnerLevel, number> = {
  iniciante: 14,
  intermediario: 22,
  avancado: 32,
};

/** Lista canônica das condições médicas oferecidas como chips no
 *  onboarding/app. `serious: true` força janela safe em metas longas
 *  (validateMedicalForGoal). Fonte única server-side — o app consome via
 *  config de admissibilidade em vez de manter cópia hardcoded. Texto
 *  livre ("Outra condição") continua coberto pelo fallback de keywords. */
export const MEDICAL_CONDITION_OPTIONS: { label: string; serious: boolean }[] = [
  { label: 'Hipertensao', serious: false },
  { label: 'Diabetes tipo 2', serious: false },
  { label: 'Asma', serious: false },
  { label: 'Historico de AVC', serious: true },
  { label: 'Problemas cardiacos', serious: true },
  { label: 'Lesao no joelho', serious: false },
  { label: 'Lesao no tornozelo', serious: false },
  { label: 'Hernia de disco', serious: true },
  { label: 'Toma anticoagulante', serious: true },
  { label: 'Toma betabloqueador', serious: false },
  { label: 'Toma insulina', serious: true },
  { label: 'Artrose', serious: false },
  { label: 'Fibromialgia', serious: false },
  { label: 'Ansiedade/depressao', serious: false },
  { label: 'Cirurgia recente (<6m)', serious: true },
];

/** Comorbidades consideradas "sérias" — qualquer match (case+diacritic
 *  insensitive) força janela safe pra metas longas (21K+). Fallback pra
 *  texto livre fora da lista canônica acima. Lista conservadora;
 *  expandir se aparecer caso real não coberto. */
export const SERIOUS_MEDICAL_KEYWORDS: string[] = [
  'cirurgia',
  'hernia',
  'anticoagulante',
  'insulina',
  'cardiac',
  'cardio',
  'avc',
  'lesao recente',
];

/** Faixas etárias que disparam restrição de janela. Master 55+ não faz
 *  agressivo em meta longa; 65+ fica em safe pra maratona. */
export const AGE_RESTRICTION_THRESHOLDS = {
  blockAggressiveAge: 55, // >= força >= feasible em 42K
  forceFeasibleHalfAge: 65, // >= força >= feasible em 21K
  forceSafeMarathonAge: 65, // >= força safe em 42K
};

/** Ceiling de % de ganho de pace por nível (em 12 semanas). Acima disso o
 *  alvo é considerado irrealista. Base: literatura de periodização — atleta
 *  iniciante ganha mais (corpo destreinado responde rápido); avançado ganha
 *  menos (curva de retorno achatada). Escalona linear por weeksCount/12. */
export const PACE_IMPROVEMENT_CEILING_PCT: Record<RunnerLevel, number> = {
  iniciante: 8.0,
  intermediario: 5.0,
  avancado: 3.0,
};

/** Retorna semanas pra (distância, nível, modo) ou null se REDIRECT. */
export function getWindowWeeks(
  distance: RaceDistanceKm,
  level: RunnerLevel,
  mode: WindowMode,
): number | null {
  const entry = RACE_WINDOWS[distance][level];
  if (mode === 'safe') return entry.safe;
  return mode === 'aggressive' ? entry.aggressive : entry.feasible;
}
