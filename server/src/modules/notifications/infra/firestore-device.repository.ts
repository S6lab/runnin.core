import { getFirestore } from '@shared/infra/firebase/firebase.client';

export interface UserDevice {
  /** Hash do token usado como ID de doc (FCM tokens são longos). */
  id: string;
  token: string;
  platform: 'ios' | 'android' | 'web' | 'unknown';
  createdAt: string;
  updatedAt: string;
}

function hashId(token: string): string {
  // Hash determinístico simples (sha1-like) sem dep extra — só pra ter um id estável
  let h = 0;
  for (let i = 0; i < token.length; i++) {
    h = ((h << 5) - h + token.charCodeAt(i)) | 0;
  }
  return `tok_${Math.abs(h).toString(36)}_${token.slice(-8)}`;
}

export class FirestoreDeviceRepository {
  private col = (userId: string) =>
    getFirestore().collection(`users/${userId}/devices`);

  async upsert(userId: string, token: string, platform: UserDevice['platform']): Promise<void> {
    const id = hashId(token);
    const now = new Date().toISOString();
    const ref = this.col(userId).doc(id);
    const existing = await ref.get();
    await ref.set(
      {
        token,
        platform,
        updatedAt: now,
        ...(existing.exists ? {} : { createdAt: now }),
      },
      { merge: true },
    );
  }

  async listByUser(userId: string): Promise<UserDevice[]> {
    const snap = await this.col(userId).get();
    return snap.docs.map(d => ({ id: d.id, ...d.data() }) as UserDevice);
  }

  async remove(userId: string, tokenId: string): Promise<void> {
    await this.col(userId).doc(tokenId).delete();
  }
}
