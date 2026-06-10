export interface Zone {
  zone: 'Z1' | 'Z2' | 'Z3' | 'Z4' | 'Z5';
  name: string;
  bpmMin: number;
  bpmMax: number;
  percentTime?: number;
}

export const ZONE_FACTORS = [0.5, 0.6, 0.7, 0.8, 0.9] as const;
export type ZoneFactor = typeof ZONE_FACTORS[number];

export const ZONE_NAMES = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'] as const;
export type ZoneName = typeof ZONE_NAMES[number];

export const ZONE_LABELS = [
  'Futurologico',
  'Manutenção',
  'Intensidade Moderada',
  'Aeróbico',
  'Anaeróbico',
] as const;
export type ZoneLabel = typeof ZONE_LABELS[number];

/** Karvonen: zona N começa em (max-rest)*factor[N] + rest, termina no início da próxima.
 *  Z5 termina em maxBpm. */
export function calculateKarvonenZone(
  maxBpm: number,
  restingBpm: number,
  factor: ZoneFactor,
): [number, number] {
  const karvonen = (maxBpm - restingBpm) * factor + restingBpm;
  if (factor === 0.9) {
    return [Math.round(karvonen), Math.ceil(maxBpm)];
  }
  const nextFactor = ZONE_FACTORS[ZONE_FACTORS.indexOf(factor) + 1]!;
  const nextZoneMin = (maxBpm - restingBpm) * nextFactor + restingBpm;
  return [Math.round(karvonen), Math.round(nextZoneMin)];
}

/** Devolve as 5 zonas Karvonen pra um perfil. */
export function computeKarvonenZones(
  maxBpm: number,
  restingBpm: number,
): { min: number; max: number }[] {
  return ZONE_FACTORS.map((f) => {
    const [min, max] = calculateKarvonenZone(maxBpm, restingBpm, f);
    return { min, max };
  });
}

/** Classifica um BPM em uma das 5 zonas (índice 0..4). null se BPM abaixo de Z1. */
export function classifyKarvonenZone(
  bpm: number,
  zones: { min: number; max: number }[],
): number | null {
  if (bpm < zones[0]!.min) return null;
  for (let i = zones.length - 1; i >= 0; i--) {
    if (bpm >= zones[i]!.min) return i;
  }
  return null;
}
