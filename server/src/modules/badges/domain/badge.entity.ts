// TF 77: sistema de badges/checkpoints.
//
// Cada badge é um marco da jornada do user (1ª corrida, 10K acumulados,
// 7 dias seguidos, etc). Definidos em código (`badge-definitions.ts`)
// como pure functions de avaliação — Firestore guarda só o estado por
// user (desbloqueou/não, quando, snapshot dos stats no momento).
//
// Cor do badge é DINÂMICA, segue skin atual do user (Artico/Magenta/
// Volt/Matrix). Server não armazena cor.

export type BadgeCategory =
  | 'first' // Primeiras vezes (one-shot)
  | 'distance_total' // Distância acumulada (10K, 50K, 100K…)
  | 'distance_run' // Distância única em uma corrida (5K, 10K, 21K…)
  | 'streak' // Dias/semanas seguidos
  | 'pace' // PRs de pace
  | 'report'; // Relatórios (semanal, mensal)

export interface BadgeStatsSnapshot {
  /** Distância usada como métrica principal do badge (km). */
  primaryValue?: number;
  /** Distância total da corrida/período relevante (km). */
  distanceKm?: number;
  /** Tempo total (segundos). */
  durationS?: number;
  /** Pace médio (formato mm:ss/km). */
  paceMinKm?: string;
  /** Melhor pace observado no período (mm:ss/km). */
  bestPaceMinKm?: string;
  /** BPM médio do período. */
  avgBpm?: number;
  /** BPM máximo do período. */
  maxBpm?: number;
  /** Quilometragem semanal/mensal (apenas pra report cards). */
  weekKm?: number;
  monthKm?: number;
  /** % de completude do plano (semanal/mensal). */
  completionPct?: number;
  /** Pace médio do PERÍODO (semana/mês). */
  periodAvgPace?: string;
  /** Outros key-value que a definição quiser carregar. */
  extra?: Record<string, string | number | boolean>;
}

export interface Badge {
  /** Slug único do badge (ex: 'first_run', 'cumulative_10k'). */
  badgeId: string;
  category: BadgeCategory;
  /** Título exibido no card (ex: "Primeira Corrida"). */
  title: string;
  /** Subtítulo curto (ex: "O começo de tudo"). */
  subtitle: string;
  /** Texto principal renderizado abaixo do número (ex: "Atingido em 16 Fev 2026"). */
  description?: string;
  /** Chip do topo do card (ex: "MARCO HISTÓRICO", "FEV 2026"). */
  badgeChip?: string;
  /** Valor numérico que aparece grande no card (ex: "01", "29.3", "7"). */
  primaryDisplay: string;
  /** Sufixo do display ("km", "dias", "corridas"). */
  primaryUnit?: string;
  /** Timestamp do desbloqueio (ms). */
  unlockedAt: number;
  /** Run/contexto associado ao desbloqueio. */
  context?: {
    runId?: string;
    weekStart?: string; // YYYY-MM-DD
    monthKey?: string; // YYYY-MM
  };
  /** Stats no momento do unlock (alimentam o card). */
  stats: BadgeStatsSnapshot;
  /** User já viu o popup. */
  seen: boolean;
  /** Quantos compartilhamentos foram registrados. */
  shareCount: number;
}
