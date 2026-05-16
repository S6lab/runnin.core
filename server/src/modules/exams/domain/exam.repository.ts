import { Exam } from './exam.entity';

export interface ExamRepository {
  create(exam: Exam): Promise<void>;
  findById(id: string, userId: string): Promise<Exam | null>;
  findByUser(userId: string, limit: number, cursor?: string): Promise<{ exams: Exam[]; nextCursor?: string }>;
  update(id: string, userId: string, data: Partial<Exam>): Promise<void>;
}
