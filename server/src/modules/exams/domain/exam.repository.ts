import { Exam } from '../domain/exam.entity';
import { ExamExtractedData } from './exam-extracted-data.entity';

export interface ExamRepository {
  create(exam: Exam): Promise<void>;
  findById(id: string, userId: string): Promise<Exam | null>;
  findByUser(userId: string, limit: number, cursor?: string): Promise<{ exams: Exam[]; nextCursor?: string }>;
  update(id: string, userId: string, data: Partial<Exam>): Promise<void>;
  softDelete(id: string, userId: string): Promise<void>;
  updateExtractedData(examId: string, userId: string, extractedData: ExamExtractedData): Promise<void>;
}
