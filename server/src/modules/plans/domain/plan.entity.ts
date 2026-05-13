export type PlanStatus = 'generating' | 'ready' | 'failed';

export type SessionStatus = 'pending' | 'completed' | 'skipped' | 'rescheduled';

export interface PlanSession {
  id: string;
  dayOfWeek: number; // 1=Mon … 7=Sun
  type: string;
  distanceKm: number;
  targetPace?: string;
  notes: string;
  status?: SessionStatus; // Session completion status
  completedAt?: string; // ISO timestamp when session was completed
  rescheduledTo?: number; // New dayOfWeek if rescheduled
}

export interface PlanWeek {
  weekNumber: number;
  sessions: PlanSession[];
  weekType?: 'load' | 'recovery'; // For 3:1 mesocycle pattern
}

export interface HeartRateZones {
  zone1: { min: number; max: number }; // Easy (60-70% max HR)
  zone2: { min: number; max: number }; // Aerobic (70-80% max HR)
  zone3: { min: number; max: number }; // Tempo (80-87% max HR)
  zone4: { min: number; max: number }; // Threshold (87-93% max HR)
  zone5: { min: number; max: number }; // VO2max (93-100% max HR)
  maxHeartRate: number;
}

export interface GenerationProgress {
  currentStage: number;
  totalStages: number;
  stageName: string;
  stageDescription: string;
}

export interface Plan {
  id: string;
  userId: string;
  goal: string;
  level: string;
  weeksCount: number;
  status: PlanStatus;
  weeks: PlanWeek[];
  heartRateZones?: HeartRateZones;
  generationProgress?: GenerationProgress;
  createdAt: string;
  updatedAt: string;
}
