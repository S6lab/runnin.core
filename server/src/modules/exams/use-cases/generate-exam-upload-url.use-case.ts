import { Exam } from '../domain/exam.entity';
import { ExamRepository } from '../domain/exam.repository';
import { GetUserFeaturesUseCase } from '@modules/subscriptions/use-cases/get-user-features.use-case';
import { ForbiddenError } from '@shared/errors/app-error';

export type GenerateUploadUrlInput = {
  examName: string;
  fileName: string;
  fileSize: number;
};

export type GenerateUploadUrlOutput = {
  uploadUrl: string;
  examId: string;
};

export class GenerateUploadUrlUseCase {
  constructor(
    private readonly repository: ExamRepository,
    private readonly getUserFeatures: GetUserFeaturesUseCase,
  ) {}

  async execute(userId: string, input: GenerateUploadUrlInput): Promise<GenerateUploadUrlOutput> {
    const plan = await this.getUserFeatures.getPlan(userId);
    const { examsPerMonth } = plan.limits;
    if (examsPerMonth > 0) {
      const now = new Date();
      const count = await this.repository.countByMonth(userId, now.getFullYear(), now.getMonth() + 1);
      if (count >= examsPerMonth) {
        throw new ForbiddenError(
          `Limite mensal de exames atingido (${examsPerMonth}/mês).`,
        );
      }
    }
    const examId = `${userId}-${Date.now()}`;
    const storagePath = `runnin-exams/${userId}/${examId}/${input.fileName}`;

    const exam: Exam = {
      id: examId,
      userId,
      examName: input.examName,
      fileName: input.fileName,
      fileSize: input.fileSize,
      storageUrl: storagePath,
      uploadedAt: new Date().toISOString(),
      coachAnalysis: null,
    };

    await this.repository.create(exam);

    return {
      uploadUrl: storagePath,
      examId,
    };
  }
}
