export type RunnerLevel = 'iniciante' | 'intermediario' | 'avancado';

export interface UserProfile {
  id: string;
  name: string;
  level: RunnerLevel;
  goal: string;
  frequency: number;
  birthDate?: string;
  weight?: string;
  height?: string;
  hasWearable: boolean;
  coachVoiceId?: string;
  premium: boolean;
  operatorId?: string;
  onboarded: boolean;
  createdAt: string;
  updatedAt: string;
}
