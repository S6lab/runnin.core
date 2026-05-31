import { z } from 'zod';
import { v4 as uuid } from 'uuid';
import { getStorageBucket } from '@shared/infra/firebase/firebase.client';
import { ExamRepository } from '../domain/exam.repository';

export const GetUploadUrlSchema = z.object({
  examName: z.string().min(1),
  fileName: z.string().min(1),
  fileSize: z.number().positive(),
});

export type GetUploadUrlInput = z.infer<typeof GetUploadUrlSchema>;

export class GetUploadUrlUseCase {
  constructor(private readonly examRepo: ExamRepository) {}

  async execute(userId: string, input: GetUploadUrlInput): Promise<{ uploadUrl: string; examId: string }> {
    const examId = uuid();
    const storagePath = `runnin-exams/${userId}/${examId}/${input.fileName}`;
    const bucket = getStorageBucket();
    const file = bucket.file(storagePath);

    const [uploadUrl] = await file.getSignedUrl({
      action: 'write',
      expires: Date.now() + 15 * 60 * 1000,
      contentType: 'application/octet-stream',
    });

    await this.examRepo.create({
      id: examId,
      userId,
      examName: input.examName,
      fileName: input.fileName,
      fileSize: input.fileSize,
      storageUrl: storagePath,
      uploadedAt: new Date().toISOString(),
    });

    return { uploadUrl, examId };
  }
}
