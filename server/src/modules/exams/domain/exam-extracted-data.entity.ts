export interface ExamExtractedData {
  summary: string;
  keyFindings: string[];
  recommendations: string[];
  metadata?: {
    examType?: 'ergometrico' | 'hemograma' | 'eletrocardiograma' | 'orto' | 'nutricional' | 'outro';
    date?: string;
    patientAge?: number;
    patientGender?: 'male' | 'female' | 'other';
  };
  vo2max?: number;
  fcMax?: number;
  fcLimiar?: number;
  ferritina?: number;
  hemoglobina?: number;
  vitaminaD?: number;
  glicemia?: number;
  colesterolLDL?: number;
  observations: string[];
  confidence: number;
  embeddedRagChunks?: RAGChunk[];
}

export interface RAGChunk {
  text: string;
  embedding: number[];
  updatedAt: string;
}
