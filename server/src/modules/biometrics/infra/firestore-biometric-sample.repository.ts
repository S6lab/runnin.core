import { getFirestore } from '@shared/infra/firebase/firebase.client';
import {
  BiometricSample,
  BiometricSampleType,
} from '../domain/biometric-sample.entity';
import { BiometricSampleRepository } from '../domain/biometric-sample.repository';

/**
 * Firestore impl. Collection: users/{uid}/biometric_samples/{sampleId}
 *
 * Doc id = `{type}_{recordedAt}` pra dedupe natural (mesma fonte enviando
 * o mesmo sample 2x sobrescreve, sem duplicar).
 *
 * Pra trocar Firestore por Mongo/SQL: implementar BiometricSampleRepository
 * em outro arquivo e re-wirar no shared/container.ts. Domain + use-cases
 * não mudam (Clean Arch).
 */
export class FirestoreBiometricSampleRepository
  implements BiometricSampleRepository
{
  private col(userId: string) {
    return getFirestore().collection(`users/${userId}/biometric_samples`);
  }

  async saveBatch(
    samples: BiometricSample[],
  ): Promise<{ saved: number; duplicates: number }> {
    if (samples.length === 0) return { saved: 0, duplicates: 0 };

    const db = getFirestore();
    const batch = db.batch();
    let duplicates = 0;

    for (const sample of samples) {
      const docId = `${sample.type}_${sample.recordedAt}`;
      const ref = this.col(sample.userId).doc(docId);
      // Conta como dedupe se já existe? Firestore set é overwrite — pra
      // saber se dedupe seria N+1 reads. Em vez disso, conta como "saved" e
      // confia no overwrite idempotente. Cliente que quiser dedupe estrito
      // implementa via createdAt comparison na app layer.
      const { id, ...data } = sample;
      void id;
      batch.set(ref, data);
    }
    await batch.commit();
    return { saved: samples.length - duplicates, duplicates };
  }

  async findLatestByType(
    userId: string,
    type: BiometricSampleType,
  ): Promise<BiometricSample | null> {
    const snap = await this.col(userId)
      .where('type', '==', type)
      .orderBy('recordedAt', 'desc')
      .limit(1)
      .get();
    if (snap.empty) return null;
    const d = snap.docs[0];
    return { id: d.id, userId, ...d.data() } as BiometricSample;
  }

  async findByDateRange(
    userId: string,
    type: BiometricSampleType | undefined,
    from: Date,
    to: Date,
  ): Promise<BiometricSample[]> {
    // Paginate cursor-based: numa janela de 7d com BPM live + steps + sleep,
    // chegamos a dezenas de milhares de samples. Limit fixo de 500 ordenado
    // ASC pegava só os primeiros — sleep ficava de fora porque vem depois
    // (mais recente). Iteramos por páginas de 1000 até esgotar, com hard cap
    // de 50k pra evitar runaway. Custo ~50k reads = ~$0.03/chamada do summary,
    // chamada poucas vezes por sessão (cache client-side).
    const PAGE = 1000;
    const HARD_CAP = 50000;
    let q = this.col(userId)
      .where('recordedAt', '>=', from.toISOString())
      .where('recordedAt', '<=', to.toISOString());
    if (type) q = q.where('type', '==', type);
    q = q.orderBy('recordedAt', 'asc');

    const all: BiometricSample[] = [];
    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    while (all.length < HARD_CAP) {
      let pageQ = q.limit(PAGE);
      if (lastDoc) pageQ = pageQ.startAfter(lastDoc);
      const snap = await pageQ.get();
      if (snap.empty) break;
      for (const d of snap.docs) {
        all.push({ id: d.id, userId, ...d.data() } as BiometricSample);
      }
      if (snap.size < PAGE) break;
      lastDoc = snap.docs[snap.size - 1];
    }
    return all;
  }

  async findByDateRangeAndTypes(
    userId: string,
    types: BiometricSampleType[],
    from: Date,
    to: Date,
  ): Promise<BiometricSample[]> {
    if (types.length === 0) return [];
    // Firestore `in` aceita até 30 valores. Se algum dia precisarmos de
    // mais, dividir em chunks de 30 e fazer query paralela.
    if (types.length > 30) {
      throw new Error(`findByDateRangeAndTypes: max 30 types, got ${types.length}`);
    }
    const PAGE = 1000;
    const HARD_CAP = 50000;
    const q = this.col(userId)
      .where('recordedAt', '>=', from.toISOString())
      .where('recordedAt', '<=', to.toISOString())
      .where('type', 'in', types)
      .orderBy('recordedAt', 'asc');

    const all: BiometricSample[] = [];
    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    while (all.length < HARD_CAP) {
      let pageQ = q.limit(PAGE);
      if (lastDoc) pageQ = pageQ.startAfter(lastDoc);
      const snap = await pageQ.get();
      if (snap.empty) break;
      for (const d of snap.docs) {
        all.push({ id: d.id, userId, ...d.data() } as BiometricSample);
      }
      if (snap.size < PAGE) break;
      lastDoc = snap.docs[snap.size - 1];
    }
    return all;
  }

  async deleteByUser(userId: string): Promise<number> {
    const snap = await this.col(userId).limit(500).get();
    if (snap.empty) return 0;
    const batch = getFirestore().batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    return snap.size;
  }
}
