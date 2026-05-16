import { ExamRepository } from '../domain/exam.repository';
import { Exam } from '../domain/exam.entity';
import { NotFoundError } from '@shared/errors/app-error';

export class FinalizeExamUseCase {
  constructor(private readonly examRepo: ExamRepository) {}

  async execute(examId: string, userId: string): Promise<Exam> {
    const exam = await this.examRepo.findById(examId, userId);
    if (!exam) throw new NotFoundError('Exam');
    return exam;
  }
}
