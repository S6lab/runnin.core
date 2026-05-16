export type RunnerLevel = 'iniciante' | 'intermediario' | 'avancado';

/**
 * UserProfile fields origin:
 * - Manual: user enters value directly
 * - Device: wearable or GPS device
 * - AI: calculated/estimated by algorithm
 */
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
  medicalConditions: string[];
  coachVoiceId?: string;
  
  // Health metrics
  restingBpm?: number;       // FC repouso (manual or wearable)
  maxBpm?: number;           // FC máxima (manual or estimated Tanaka)
  
  // Coach preferences
  coachPersonality?: 'motivador' | 'tecnico' | 'sereno';
  coachMessageFrequency?: 'per_km' | 'per_2km' | 'alerts_only' | 'silent';
  coachFeedbackEnabled?: Record<string, boolean>;
  
  // Notifications
  notificationsEnabled?: Record<string, boolean>;
  dndWindow?: { start: string; end: string };
  
  // Units and formatting
  unitsSystem?: 'metric' | 'imperial';
  paceFormat?: 'min_per_km' | 'min_per_mi';
  timeFormat?: '24h' | '12h';
  
  premium: boolean;
  premiumUntil?: string;
  lastOnboardingAt?: string;
  operatorId?: string;
  onboarded: boolean;
  createdAt: string;
  updatedAt: string;
}

export function isPremium(profile: Pick<UserProfile, 'premium' | 'premiumUntil'> | null | undefined): boolean {
  if (!profile) return false;
  if (profile.premium) return true;
  if (!profile.premiumUntil) return false;
  return new Date(profile.premiumUntil).getTime() > Date.now();
}
