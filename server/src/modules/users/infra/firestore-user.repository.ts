import { FieldPath } from 'firebase-admin/firestore';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { UserProfile } from '../domain/user.entity';
import { UserRepository } from '../domain/user.repository';

export class FirestoreUserRepository implements UserRepository {
  private col = () => getFirestore().collection('users');

  async findById(id: string): Promise<UserProfile | null> {
    const doc = await this.col().doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, ...doc.data() } as UserProfile;
  }

  async upsert(profile: UserProfile): Promise<void> {
    const { id, ...data } = profile;
    await this.col().doc(id).set({ ...data, updatedAt: new Date().toISOString() }, { merge: true });
  }

  async archiveOnboarding(userId: string, snapshot: UserProfile): Promise<void> {
    const archivedAt = new Date().toISOString();
    const { id: _id, ...data } = snapshot;
    await getFirestore()
      .collection(`users/${userId}/onboarding_history`)
      .doc(archivedAt)
      .set({ ...data, archivedAt });
  }

  async list(limit?: number, startAfterId?: string): Promise<UserProfile[]> {
    let query = this.col()
      .orderBy(FieldPath.documentId())
      .limit(limit || 100);
    if (startAfterId) {
      query = query.startAfter(startAfterId);
    }
    const snapshot = await query.get();
    const users: UserProfile[] = [];
    snapshot.forEach(doc => {
      users.push({ id: doc.id, ...doc.data() } as UserProfile);
    });
    return users;
  }
}
