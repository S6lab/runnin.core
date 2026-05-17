import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Notification } from '../domain/notification.entity';
import { NotificationRepository } from '../domain/notification.repository';

function stripUndefined<T extends object>(data: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(data).filter(([, value]) => value !== undefined),
  ) as Partial<T>;
}

export class FirestoreNotificationRepository implements NotificationRepository {
  private col = (userId: string) =>
    getFirestore().collection(`users/${userId}/notifications`);

  async findById(userId: string, id: string): Promise<Notification | null> {
    const doc = await this.col(userId).doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, userId, ...doc.data() } as Notification;
  }

  async listActive(userId: string): Promise<Notification[]> {
    const snap = await this.col(userId)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();
    return snap.docs
      .map(d => ({ id: d.id, userId, ...d.data() }) as Notification)
      .filter(n => !n.dismissedAt);
  }

  async createIfAbsent(notification: Notification): Promise<Notification> {
    const { id, userId, ...data } = notification;
    const ref = this.col(userId).doc(id);
    const db = getFirestore();

    return db.runTransaction(async tx => {
      const snap = await tx.get(ref);
      if (snap.exists) {
        return { id: snap.id, userId, ...snap.data() } as Notification;
      }
      tx.set(ref, stripUndefined(data));
      return notification;
    });
  }

  async upsertPreserveUserState(
    notification: Notification,
  ): Promise<Notification> {
    const { id, userId, ...data } = notification;
    const ref = this.col(userId).doc(id);
    const db = getFirestore();

    return db.runTransaction(async tx => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, stripUndefined(data));
        return notification;
      }
      const existing = snap.data() as Partial<Notification>;
      // Mantém estado do user (lido, dispensado) e merge do conteúdo novo.
      const merged = {
        ...stripUndefined(data),
        ...(existing.dismissedAt ? { dismissedAt: existing.dismissedAt } : {}),
        ...(existing.readAt ? { readAt: existing.readAt } : {}),
        ...(existing.createdAt ? { createdAt: existing.createdAt } : {}),
      };
      tx.set(ref, merged);
      return { id, userId, ...merged } as Notification;
    });
  }

  async dismiss(userId: string, id: string, at: string): Promise<void> {
    await this.col(userId).doc(id).update({ dismissedAt: at });
  }

  async dismissAll(userId: string, at: string): Promise<number> {
    const snap = await this.col(userId).get();
    const db = getFirestore();
    const batch = db.batch();
    let count = 0;

    for (const doc of snap.docs) {
      const data = doc.data() as Notification;
      if (data.dismissedAt) continue;
      batch.update(doc.ref, { dismissedAt: at });
      count += 1;
    }

    if (count > 0) await batch.commit();
    return count;
  }

  async markRead(userId: string, id: string, at: string): Promise<void> {
    await this.col(userId).doc(id).update({ readAt: at });
  }
}
