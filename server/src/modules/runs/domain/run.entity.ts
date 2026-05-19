export type RunStatus = 'active' | 'completed' | 'abandoned';

export interface KmSplit {
  kmIndex: number;
  durationS: number;
  avgPaceMinKm: string;
  avgBpm?: number;
  /** Calorias estimadas (kcal) do km — server preenche em CompleteRunUseCase
   *  usando MET escalonado por pace × peso × tempo do km. */
  calories?: number;
  /** Ganho de elevação (m) do km — soma de deltas positivos de altitude
   *  dos GPS points dentro do km. Null quando o device não emite altitude. */
  elevationGain?: number;
}

export interface GpsPoint {
  lat: number;
  lng: number;
  ts: number;       // Unix ms
  accuracy: number; // metros
  altitude?: number; // metros (acima do nível do mar; opcional, depende do device)
  pace?: number;    // min/km
  bpm?: number;
}

export interface Run {
  id: string;
  userId: string;
  status: RunStatus;
  type: string;
  targetPace?: string;
  targetDistance?: string;
  planSessionId?: string;
  distanceM: number;
  durationS: number;
  avgPace?: string;
  avgBpm?: number;
  maxBpm?: number;
  cadence?: number;        // spm (steps per minute)
  elevationGain?: number;  // metros
  /** Calorias estimadas (kcal) gastas na corrida. Calculado em
   *  CompleteRunUseCase via MET × peso(kg) × tempo(h). MET varia por
   *  pace: 6.0 (caminhada 5km/h) ... 12.5 (8min/km) ... 16.0 (4min/km). */
  calories?: number;
  xpEarned?: number;
  coachReportId?: string;
  splits?: KmSplit[];
  createdAt: string;
  completedAt?: string;
}
