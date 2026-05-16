export type RunStatus = 'active' | 'completed' | 'abandoned';

export interface GpsPoint {
  lat: number;
  lng: number;
  ts: number;       // Unix ms
  accuracy: number; // metros
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
  xpEarned?: number;
  coachReportId?: string;
  createdAt: string;
  completedAt?: string;
}
