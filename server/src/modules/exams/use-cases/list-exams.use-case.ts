import { ExamRepository } from '../domain/exam.repository';
import { Exam } from '../domain/exam.entity';

const DEFAULT_LIMIT = 20;

export class ListExamsUseCase {
  constructor(private readonly examRepo: ExamRepository) {}

  async execute(userId: string, cursor?: string): Promise<{ exams: Exam[]; nextCursor?: string }> {
    return this.examRepo.findByUser(userId, DEFAULT_LIMIT, cursor);
  }
}
