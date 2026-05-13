import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { UserGamification, BadgeId, calcLevel } from '../domain/gamification.entity';
import { GamificationRepository } from '../domain/gamification.repository';

function stripUndefined<T extends object>(data: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(data).filter(([, value]) => value !== undefined),
  ) as Partial<T>;
}

export class FirestoreGamificationRepository implements GamificationRepository {
  private doc = (userId: string) =>
    getFirestore().collection(`users/${userId}/gamification`).doc('profile');

  async findByUserId(userId: string): Promise<UserGamification | null> {
    const snap = await this.doc(userId).get();
    if (!snap.exists) return null;
    return { userId, ...snap.data() } as UserGamification;
  }

  async upsert(data: UserGamification): Promise<void> {
    const { userId, ...rest } = data;
    await this.doc(userId).set(stripUndefined(rest), { merge: true });
  }

  async awardXp(userId: string, xp: number): Promise<UserGamification> {
    const existing = await this.findByUserId(userId);
    const now = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

    let currentStreak = existing?.currentStreak ?? 0;
    let longestStreak = existing?.longestStreak ?? 0;
    const lastActivityDate = existing?.lastActivityDate ?? null;

    if (lastActivityDate === null) {
      currentStreak = 1;
    } else if (lastActivityDate === now) {
      // same day — no change to streak
    } else {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      const yesterdayStr = yesterday.toISOString().slice(0, 10);
      if (lastActivityDate === yesterdayStr) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }
    }

    if (currentStreak > longestStreak) longestStreak = currentStreak;

    const totalXp = (existing?.totalXp ?? 0) + xp;
    const updated: UserGamification = {
      userId,
      totalXp,
      level: calcLevel(totalXp),
      currentStreak,
      longestStreak,
      lastActivityDate: now,
      unlockedBadges: existing?.unlockedBadges ?? [],
      updatedAt: new Date().toISOString(),
    };

    await this.upsert(updated);
    return updated;
  }

  async unlockBadge(userId: string, badgeId: BadgeId): Promise<void> {
    const existing = await this.findByUserId(userId);
    const badges = existing?.unlockedBadges ?? [];
    if (badges.includes(badgeId)) return;

    const updated: UserGamification = {
      userId,
      totalXp: existing?.totalXp ?? 0,
      level: existing?.level ?? 1,
      currentStreak: existing?.currentStreak ?? 0,
      longestStreak: existing?.longestStreak ?? 0,
      lastActivityDate: existing?.lastActivityDate ?? null,
      unlockedBadges: [...badges, badgeId],
      updatedAt: new Date().toISOString(),
    };

    await this.upsert(updated);
  }
}
