export const BADGES = {
  first_run: { id: 'first_run', name: 'First Run', description: 'Complete your first run' },
  week_warrior: { id: 'week_warrior', name: 'Week Warrior', description: '7-day running streak' },
  marathon_ready: { id: 'marathon_ready', name: 'Marathon Ready', description: 'Complete a marathon distance (42.195 km)' },
  speed_demon: { id: 'speed_demon', name: 'Speed Demon', description: 'Achieve a pace under 4:00/km' },
} as const;

export type BadgeId = keyof typeof BADGES;

export interface Badge {
  id: BadgeId;
  name: string;
  description: string;
  unlockedAt?: string;
}

export interface UserGamification {
  userId: string;
  totalXp: number;
  level: number;
  currentStreak: number;
  longestStreak: number;
  lastActivityDate: string | null;
  unlockedBadges: BadgeId[];
  updatedAt: string;
}

export function calcLevel(totalXp: number): number {
  return Math.floor(Math.sqrt(totalXp / 100)) + 1;
}
