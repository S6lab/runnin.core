import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Exam } from '../domain/exam.entity';
import { ExamRepository } from '../domain/exam.repository';

function stripUndefined<T extends object>(data: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(data).filter(([, value]) => value !== undefined),
  ) as Partial<T>;
}

export class FirestoreExamRepository implements ExamRepository {
  private col = (userId: string) => getFirestore().collection(`users/${userId}/exams`);

  async create(exam: Exam): Promise<void> {
    const { id, userId, ...data } = exam;
    await this.col(userId).doc(id).set(stripUndefined(data));
  }

  async findById(id: string, userId: string): Promise<Exam | null> {
    const doc = await this.col(userId).doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, userId, ...doc.data() } as Exam;
  }

  async findByUser(userId: string, limit: number, cursor?: string): Promise<{ exams: Exam[]; nextCursor?: string }> {
    let query = this.col(userId)
      .where('deletedAt', '==', null)
      .orderBy('uploadedAt', 'desc')
      .limit(limit + 1);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    const docs = snap.docs;
    const hasMore = docs.length > limit;
    const exams = docs.slice(0, limit).map(d => ({ id: d.id, userId, ...d.data() }) as Exam);
    return { exams, nextCursor: hasMore ? exams[exams.length - 1].uploadedAt : undefined };
  }

  async update(id: string, userId: string, data: Partial<Exam>): Promise<void> {
    await this.col(userId)
      .doc(id)
      .update(stripUndefined(data as Record<string, unknown>));
  }
}
