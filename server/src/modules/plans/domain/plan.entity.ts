export type PlanStatus = 'generating' | 'ready' | 'failed';

export interface PlanSession {
  id: string;
  dayOfWeek: number; // 1=Mon … 7=Sun
  type: string;
  distanceKm: number;
  targetPace?: string;
  notes: string;
}

export interface PlanWeek {
  weekNumber: number;
  sessions: PlanSession[];
}

export interface Plan {
  id: string;
  userId: string;
  goal: string;
  level: string;
  weeksCount: number;
  status: PlanStatus;
  weeks: PlanWeek[];
  createdAt: string;
  updatedAt: string;
}
