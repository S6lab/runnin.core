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
}
