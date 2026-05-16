import { PlanWeek } from './plan.entity';

export type PlanRevisionRequestType =
  | 'more_load'
  | 'less_load'
  | 'more_days'
  | 'less_days'
  | 'more_tempo'
  | 'more_resistance'
  | 'more_intervals'
  | 'change_days'
  | 'pain_or_discomfort'
  | 'other';

export type PlanRevisionStatus = 'pending' | 'applied' | 'cancelled' | 'failed';

export interface PlanRevision {
  id: string;
  planId: string;
  userId: string;
  weekIndex: number;          // weekNumber afetado (geralmente a semana atual)
  requestType: PlanRevisionRequestType;
  subOption?: string;         // "+5km/semana" | "+10km/semana" | etc.
  freeText?: string;          // quando requestType === 'other'
  oldWeeksSnapshot: PlanWeek[]; // snapshot pre-mudança
  newWeeksSnapshot?: PlanWeek[]; // snapshot pos-mudança (null se pending)
  coachExplanation: string;   // texto LLM explicando o que vai fazer
  status: PlanRevisionStatus;
  createdAt: string;
  appliedAt?: string;
}
