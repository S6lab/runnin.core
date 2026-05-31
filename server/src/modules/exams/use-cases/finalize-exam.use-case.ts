import { ExamRepository } from '../domain/exam.repository';
import { Exam } from '../domain/exam.entity';
import { AnalyzeExamUseCase } from './analyze-exam.use-case';
import { NotFoundError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

export class FinalizeExamUseCase {
  constructor(
    private readonly examRepo: ExamRepository,
    private readonly analyzeExam?: AnalyzeExamUseCase,
  ) {}

  async execute(examId: string, userId: string): Promise<Exam> {
    const exam = await this.examRepo.findById(examId, userId);
    if (!exam) throw new NotFoundError('Exam');

    if (this.analyzeExam && exam.storageUrl) {
      this.triggerAnalyzeExam(examId, userId);
    }

    return exam;
  }

  private triggerAnalyzeExam(examId: string, userId: string): void {
    this.analyzeExam?.execute(examId, userId).catch(err => {
      logger.warn('finalize_exam.analyze_failed', { examId, err: String(err) });
    });
  }
}
