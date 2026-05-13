import { UserGamification, BadgeId } from './gamification.entity';

export interface GamificationRepository {
  findByUserId(userId: string): Promise<UserGamification | null>;
  upsert(data: UserGamification): Promise<void>;
  awardXp(userId: string, xp: number): Promise<UserGamification>;
  unlockBadge(userId: string, badgeId: BadgeId): Promise<void>;
}
