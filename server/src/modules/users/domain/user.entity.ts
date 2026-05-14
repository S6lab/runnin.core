export type RunnerLevel = 'iniciante' | 'intermediario' | 'avancado';

export interface RunAlertPreferences {
  paceAlertsEnabled: boolean;
  paceAlertFrequency: 'every_km' | 'every_500m' | 'off';
  hrZoneAlertsEnabled: boolean;
  distanceMilestonesEnabled: boolean;
  distanceMilestones: number[];
  timeMilestonesEnabled: boolean;
  timeMilestones: number[];
}

export interface MusicPreferences {
  serviceEnabled: boolean;
  lastService?: 'device' | 'spotify' | 'youtube_music' | 'apple_music';
  lastVolume: number;
}

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
  paceTarget?: string;
  preferredRunTime?: string;
  wakeUpTime?: string;
  sleepTime?: string;
  coachVoiceId?: string;
  premium: boolean;
  premiumUntil?: string;
  lastOnboardingAt?: string;
  operatorId?: string;
  onboarded: boolean;
  hasCompletedFirstRun: boolean;
  runAlertPreferences?: RunAlertPreferences;
  musicPreferences?: MusicPreferences;
  createdAt: string;
  updatedAt: string;
}

export function isPremium(profile: Pick<UserProfile, 'premium' | 'premiumUntil'> | null | undefined): boolean {
  if (!profile) return false;
  if (profile.premium) return true;
  if (!profile.premiumUntil) return false;
  return new Date(profile.premiumUntil).getTime() > Date.now();
}
