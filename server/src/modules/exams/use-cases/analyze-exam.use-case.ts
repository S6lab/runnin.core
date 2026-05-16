import { ExamRepository } from '../domain/exam.repository';
import { ExamExtractedData } from '../domain/exam-extracted-data.entity';
import { GeminiMultimodalService } from '@shared/infra/llm/gemini-multimodal.service';
import { FirestoreExamRepository } from '../infra/firestore-exam.repository';
import { getStorageBucket } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

export class AnalyzeExamUseCase {
  constructor(
    private readonly examRepo: ExamRepository = new FirestoreExamRepository(),
    private readonly geminiMultimodal: GeminiMultimodalService =
      new GeminiMultimodalService(),
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

      const extractedData = await this.analyzeExamContent(
        examData.buffer,
        examData.mimeType,
      );

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

  private async downloadExamFile(storageUrl: string): Promise<{
    buffer: Buffer;
    mimeType: string;
  } | null> {
    try {
      const bucket = getStorageBucket();
      const fileName = storageUrl.split('/').pop() || 'exam';
      const file = bucket.file(fileName);

      const metadata = await file.getMetadata();
      const mimeType =
        (metadata[0]?.contentType as string) || 'application/pdf';

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

  private async analyzeExamContent(
    buffer: Buffer,
    mimeType: string,
  ): Promise<ExamExtractedData> {
    const prompt = this.buildAnalysisPrompt(mimeType);

    const responseText =
      await this.geminiMultimodal.analyzeExamDocument(
        prompt,
        buffer,
        mimeType,
      );

    return this.parseAnalysisResponse(responseText);
  }

  private buildAnalysisPrompt(mimeType: string): string {
    return `Você é um assistente médico especializado em analisar documentos de exames médicos.

Analise o documento de exame fornecido e retorne um resumo estruturado em JSON com:
1. summary: Um resumo conciso do documento, destacando o tipo de exame e principais achados
2. keyFindings: Uma lista com os principais achados ou resultados relevantes
3. recommendations: Uma lista com recomendações baseadas no exame (se aplicável)
4. metadata: Informações estruturadas como tipo de exame, data do exame, idade e gênero do paciente (se disponível)

Retorne apenas o objeto JSON válido sem texto adicional. Use português brasileiro.

Formato esperado:
{
  "summary": "...",
  "keyFindings": ["...", "..."],
  "recommendations": ["...", "..."],
  "metadata": {
    "examType": "...",
    "date": "...",
    "patientAge": ...,
    "patientGender": "..."
  }
}`;
  }

  private parseAnalysisResponse(
    responseText: string,
  ): ExamExtractedData {
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0]) as ExamExtractedData;
        if (parsed.summary && Array.isArray(parsed.keyFindings)) {
          return parsed;
        }
      }
    } catch (err) {
      logger.warn('analyze_exam.parse_failed', {
        err: err instanceof Error ? err.message : String(err),
      });
    }

    return this.createFallbackExtractedData(responseText);
  }

  private createFallbackExtractedData(
    responseText: string,
  ): ExamExtractedData {
    return {
      summary:
        responseText.slice(0, 500) ||
        'Não foi possível analisar o documento do exame.',
      keyFindings: [],
      recommendations: [],
      metadata: {},
    };
  }
}
