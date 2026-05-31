import { ExamExtractedData } from './exam-extracted-data.entity';

export interface Exam {
  id: string;
  userId: string;
  examName: string;
  fileName: string;
  fileSize: number;
  storageUrl: string;
  uploadedAt: string;
  coachAnalysis?: string | null;
  extractedData?: ExamExtractedData;
  deletedAt?: string;
}
