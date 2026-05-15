import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { CoachReportRepository } from '../domain/coach-report.repository';

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente.
Gere análises técnicas de corrida em português brasileiro, falando diretamente com o corredor.
Seja específico com dados reais fornecidos e transforme a análise em orientação prática.
Tom humano, firme e motivador, como feedback pós-treino. Máximo 3 parágrafos curtos. Sem emojis.`;

export class GenerateReportUseCase {
  private llm = getAsyncLLM();

  constructor(
    private readonly reports: CoachReportRepository,
    private readonly runs: RunRepository,
  ) {}

  async execute(run: Run, userId: string): Promise<string> {
    const dist = (run.distanceM / 1000).toFixed(2);
    const minutes = Math.floor(run.durationS / 60);
    const knowledgeContext = await formatRunningKnowledgeContext(
      `${run.type} corrida ${dist}km pace ${run.avgPace ?? ''} bpm ${run.avgBpm ?? ''}`,
      3,
    );

    const prompt = `Analise esta corrida:
- Tipo: ${run.type}
- Distância: ${dist}km
- Duração: ${minutes} minutos
- Pace médio: ${run.avgPace ?? 'N/A'}/km
- BPM médio: ${run.avgBpm ?? 'N/A'}
- BPM máximo: ${run.maxBpm ?? 'N/A'}
${run.targetPace ? `- Pace alvo: ${run.targetPace}/km` : ''}

Dê um feedback de personal trainer com: (1) avaliação do desempenho, (2) pontos de melhoria, (3) sugestão para próxima sessão.

Base de conhecimento:
${knowledgeContext}`;

    try {
      const summary = await this.llm.generate(prompt, { systemPrompt: SYSTEM_PROMPT, maxTokens: 400 });
      const reportId = run.id;

      await this.reports.save({
        runId: reportId,
        userId,
        summary,
        status: 'ready',
        generatedAt: new Date().toISOString(),
      });

      await this.runs.update(run.id, userId, { coachReportId: reportId });

      return reportId;
    } catch (err) {
      logger.error('coach.report.failed', { runId: run.id, err });
      throw err;
    }
  }
}
