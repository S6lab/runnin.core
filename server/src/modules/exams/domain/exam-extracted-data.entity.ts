export interface ExamExtractedData {
  summary: string;
  keyFindings: string[];
  recommendations: string[];
  metadata?: {
    examType?: string;
    date?: string;
    patientAge?: number;
    patientGender?: 'male' | 'female' | 'other';
  };
}
