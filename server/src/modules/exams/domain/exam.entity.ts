export interface Exam {
  id: string;
  userId: string;
  examName: string;
  fileName: string;
  fileSize: number;
  storageUrl: string;
  uploadedAt: string;
  coachAnalysis?: string;
  deletedAt?: string;
}
