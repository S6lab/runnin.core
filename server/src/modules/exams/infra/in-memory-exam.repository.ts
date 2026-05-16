import { ExamRepository } from '../domain/exam.repository';
import { NotFoundError } from '@shared/errors/app-error';
import { Exam } from '../domain/exam.entity';

export class InMemoryExamRepository implements ExamRepository {
  private exams: Map<string, Exam> = new Map();

  async create(exam: Exam): Promise<void> {
    this.exams.set(exam.id, exam);
  }

  async findById(id: string, userId: string): Promise<Exam | null> {
    const exam = this.exams.get(id);
    if (!exam || exam.userId !== userId) return null;
    return exam;
  }

  async findByUser(userId: string, limit: number, cursor?: string): Promise<{ exams: Exam[]; nextCursor?: string }> {
    const userExams = Array.from(this.exams.values()).filter(e => e.userId === userId);
    const start = cursor ? userExams.findIndex(e => e.id === cursor) + 1 : 0;
    const end = start + limit;
    const exams = userExams.slice(start, end);
    return {
      exams,
      nextCursor: end < userExams.length ? exams[exams.length - 1]?.id : undefined,
    };
  }

  async update(id: string, userId: string, data: Partial<Exam>): Promise<void> {
    const exam = await this.findById(id, userId);
    if (!exam) throw new NotFoundError('Exam');
    const updated = { ...exam, ...data };
    this.exams.set(id, updated);
  }

  async softDelete(id: string, userId: string): Promise<void> {
    const exam = await this.findById(id, userId);
    if (!exam) throw new NotFoundError('Exam');
    await this.update(id, userId, { deletedAt: new Date().toISOString() });
  }
}
