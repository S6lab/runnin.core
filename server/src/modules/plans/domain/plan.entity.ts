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
  focus?: string;       // "Base" | "Intervalado" | "Tempo" | "Recuperação"
  narrative?: string;   // texto LLM da semana (1-2 frases)
}

export interface Plan {
  id: string;
  userId: string;
  goal: string;
  level: string;
  weeksCount: number;
  status: PlanStatus;
  weeks: PlanWeek[];
  mesocycleNarrative?: string; // texto LLM do mesociclo (3-4 frases)
  createdAt: string;
  updatedAt: string;
}
