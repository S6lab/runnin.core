import { Exam } from '../domain/exam.entity';
import { ExamRepository } from '../domain/exam.repository';

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
  constructor(private readonly repository: ExamRepository) {}

  async execute(userId: string, input: GenerateUploadUrlInput): Promise<GenerateUploadUrlOutput> {
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
