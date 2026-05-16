import { ExamRepository } from '../domain/exam.repository';
import { NotFoundError } from '@shared/errors/app-error';

export class DeleteExamUseCase {
  constructor(private readonly examRepo: ExamRepository) {}

  async execute(examId: string, userId: string): Promise<void> {
    const exam = await this.examRepo.findById(examId, userId);
    if (!exam) throw new NotFoundError('Exam');
    await this.examRepo.update(examId, userId, { deletedAt: new Date().toISOString() });
  }
}
