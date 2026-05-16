import { ExamRepository } from '../domain/exam.repository';
import { ExamExtractedData, RAGChunk } from '../domain/exam-extracted-data.entity';
import { GeminiMultimodalService } from '@shared/infra/llm/gemini-multimodal.service';
import { FirestoreExamRepository } from '../infra/firestore-exam.repository';
import { getStorageBucket } from '@shared/infra/firebase/firebase.client';
import { buildExamAnalysisPrompt } from '@shared/infra/llm/prompts';
import { CoachRuntimeContextService } from '@modules/coach/use-cases/coach-runtime-context.service';
import { logger } from '@shared/logger/logger';

interface OCRResponse {
  summary: string;
  keyFindings: string[];
  recommendations: string[];
  observations: string[];
  confidence: number;
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
}

const EXAM_SCHEMA = `{
  "summary": string,                  // resumo executivo do exame (1-3 frases)
  "keyFindings": string[],            // achados clínicos principais
  "recommendations": string[],        // recomendações conservadoras para um corredor
  "observations": string[],           // observações adicionais relevantes
  "confidence": number,               // 0..1 — certeza da extração
  "metadata": {
    "examType"?: "ergometrico"|"hemograma"|"eletrocardiograma"|"orto"|"nutricional"|"outro",
    "date"?: string,
    "patientAge"?: number,
    "patientGender"?: "male"|"female"|"other"
  },
  "vo2max"?: number, "fcMax"?: number, "fcLimiar"?: number,
  "ferritina"?: number, "hemoglobina"?: number, "vitaminaD"?: number,
  "glicemia"?: number, "colesterolLDL"?: number
}`;

export class AnalyzeExamUseCase {
  private runtime = new CoachRuntimeContextService();

  constructor(
    private readonly examRepo: ExamRepository = new FirestoreExamRepository(),
    private readonly geminiMultimodal: GeminiMultimodalService = new GeminiMultimodalService(),
  ) {}

  async execute(examId: string, userId: string): Promise<void> {
    try {
      const exam = await this.examRepo.findById(examId, userId);
      if (!exam) {
        logger.warn('analyze_exam.not_found', { examId, userId });
        return;
      }
      if (!exam.storageUrl) {
        logger.warn('analyze_exam.no_storage_url', { examId, userId });
        return;
      }

      const examData = await this.downloadExamFile(exam.storageUrl);
      if (!examData) {
        logger.warn('analyze_exam.download_failed', { examId, userId });
        return;
      }

      const extractedData = await this.analyzeExamContent(examData.buffer, examData.mimeType, userId);
      await this.examRepo.updateExtractedData(examId, userId, extractedData);

      logger.info('analyze_exam.completed', {
        examId,
        userId,
        summaryLength: extractedData.summary.length,
      });
    } catch (err) {
      logger.error('analyze_exam.failed', {
        examId,
        userId,
        err: err instanceof Error ? err.message : String(err),
      });
    }
  }

  private async downloadExamFile(storageUrl: string): Promise<{ buffer: Buffer; mimeType: string } | null> {
    try {
      const bucket = getStorageBucket();
      const fileName = storageUrl.split('/').pop() || 'exam';
      const file = bucket.file(fileName);

      const metadata = await file.getMetadata();
      const mimeType = (metadata[0]?.contentType as string) || 'application/pdf';

      const [buffer] = await file.download();
      return { buffer, mimeType };
    } catch (err) {
      logger.error('analyze_exam.download_error', {
        storageUrl,
        err: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
  }

  private async analyzeExamContent(buffer: Buffer, _mimeType: string, userId: string): Promise<ExamExtractedData> {
    const runtime = await this.runtime.getContext(userId);
    const built = await buildExamAnalysisPrompt({ profile: runtime.profile, schema: EXAM_SCHEMA });

    logger.info('exam.analyze.prompt', { userId, version: built.version, source: built.source });

    const prompt = `${built.systemPrompt}\n\n${built.userPrompt}`;
    const responseText = await this.geminiMultimodal.analyzeExamDocument(prompt, buffer, _mimeType);

    const ocrResponse = this.parseOCRResponse(responseText);

    const extractedData: ExamExtractedData = {
      summary: ocrResponse.summary,
      keyFindings: ocrResponse.keyFindings,
      recommendations: ocrResponse.recommendations,
      observations: ocrResponse.observations,
      confidence: ocrResponse.confidence,
      metadata: ocrResponse.metadata,
      vo2max: ocrResponse.vo2max,
      fcMax: ocrResponse.fcMax,
      fcLimiar: ocrResponse.fcLimiar,
      ferritina: ocrResponse.ferritina,
      hemoglobina: ocrResponse.hemoglobina,
      vitaminaD: ocrResponse.vitaminaD,
      glicemia: ocrResponse.glicemia,
      colesterolLDL: ocrResponse.colesterolLDL,
    };

    const ragChunks = await this.createRAGChunks(extractedData);
    if (ragChunks.length > 0) {
      extractedData.embeddedRagChunks = ragChunks;
    }

    return extractedData;
  }

  private parseOCRResponse(responseText: string): OCRResponse {
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]) as Partial<OCRResponse>;
        if (parsed && typeof parsed.confidence === 'number') {
          return {
            summary: parsed.summary ?? '',
            keyFindings: parsed.keyFindings ?? [],
            recommendations: parsed.recommendations ?? [],
            observations: parsed.observations ?? [],
            confidence: parsed.confidence,
            metadata: parsed.metadata,
            vo2max: parsed.vo2max,
            fcMax: parsed.fcMax,
            fcLimiar: parsed.fcLimiar,
            ferritina: parsed.ferritina,
            hemoglobina: parsed.hemoglobina,
            vitaminaD: parsed.vitaminaD,
            glicemia: parsed.glicemia,
            colesterolLDL: parsed.colesterolLDL,
          };
        }
      }
    } catch (err) {
      logger.warn('analyze_exam.parseOCR_failed', {
        err: err instanceof Error ? err.message : String(err),
      });
    }

    return this.createFallbackOCRResponse(responseText);
  }

  private createFallbackOCRResponse(responseText: string): OCRResponse {
    return {
      summary: responseText.slice(0, 500) || 'Não foi possível analisar o documento do exame.',
      keyFindings: [],
      recommendations: [],
      observations: [],
      confidence: 0.3,
    };
  }

  private async createRAGChunks(extractedData: ExamExtractedData): Promise<RAGChunk[]> {
    const chunks: RAGChunk[] = [];
    const timestamp = new Date().toISOString();

    if (!extractedData.summary) return chunks;

    const examTypeText = extractedData.metadata?.examType
      ? `Tipo de exame: ${extractedData.metadata.examType}.`
      : '';

    const biomarkersText = Object.entries({
      vo2max: extractedData.vo2max,
      fcMax: extractedData.fcMax,
      fcLimiar: extractedData.fcLimiar,
      ferritina: extractedData.ferritina,
      hemoglobina: extractedData.hemoglobina,
      vitaminaD: extractedData.vitaminaD,
      glicemia: extractedData.glicemia,
      colesterolLDL: extractedData.colesterolLDL,
    })
      .filter(([, value]) => value !== undefined)
      .map(([key, value]) => `${key}: ${value}`)
      .join(', ');

    const summaryText = [
      examTypeText,
      `Resumo: ${extractedData.summary}`,
      biomarkersText ? `Achados biométricos: ${biomarkersText}.` : '',
      extractedData.keyFindings.length > 0 ? `Principais achados: ${extractedData.keyFindings.join('; ')}.` : '',
      extractedData.recommendations.length > 0 ? `Recomendações: ${extractedData.recommendations.join('; ')}.` : '',
    ]
      .filter(Boolean)
      .join(' ');

    chunks.push({
      text: summaryText,
      embedding: [],
      updatedAt: timestamp,
    });

    return chunks;
  }
}
