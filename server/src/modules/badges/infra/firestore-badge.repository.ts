import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Badge } from '../domain/badge.entity';
import { BadgeRepository } from '../domain/badge.repository';

function stripUndefined<T extends object>(data: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(data).filter(([, value]) => value !== undefined),
  ) as Partial<T>;
}

export class FirestoreBadgeRepository implements BadgeRepository {
  private col = (uid: string) => getFirestore().collection(`users/${uid}/badges`);

  async listByUser(uid: string): Promise<Badge[]> {
    const snap = await this.col(uid).orderBy('unlockedAt', 'desc').get();
    return snap.docs.map((d) => d.data() as Badge);
  }

  async findByUser(uid: string, badgeId: string): Promise<Badge | null> {
    const doc = await this.col(uid).doc(badgeId).get();
    return doc.exists ? (doc.data() as Badge) : null;
  }

  async save(uid: string, badge: Badge): Promise<void> {
    await this.col(uid).doc(badge.badgeId).set(stripUndefined(badge));
  }

  async markSeen(uid: string, badgeId: string): Promise<void> {
    await this.col(uid).doc(badgeId).update({ seen: true });
  }

  async incrementShare(uid: string, badgeId: string): Promise<void> {
    // FieldValue.increment não é importado por padrão — usamos transação simples.
    const ref = this.col(uid).doc(badgeId);
    await getFirestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = (snap.data() as Badge | undefined)?.shareCount ?? 0;
      tx.update(ref, { shareCount: current + 1 });
    });
  }
}
