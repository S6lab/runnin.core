import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente.
Gere análises técnicas de corrida em português brasileiro, falando diretamente com o corredor.
Seja específico com dados reais fornecidos e transforme a análise em orientação prática.
Tom humano, firme e motivador, como feedback pós-treino. Máximo 3 parágrafos curtos. Sem emojis.`;

export interface PeriodAnalysisRun {
  id: string;
  distanceM: number;
  durationS: number;
  avgPace?: string;
  avgBpm?: number;
  maxBpm?: number;
  type: string;
  date: string;
}

export interface PeriodAnalysis {
  userId: string;
  runs: PeriodAnalysisRun[];
  summary: string;
  status: 'ready';
  generatedAt: string;
}

export class GeneratePeriodAnalysisUseCase {
  private llm = getAsyncLLM();

  constructor(private readonly runs: RunRepository) {}

  async execute(userId: string, limit: number = 10, cursor?: string): Promise<PeriodAnalysis> {
    const { runs: periodRuns } = await this.runs.findByUser(userId, limit, cursor);

    if (periodRuns.length === 0) {
      return {
        userId,
        runs: [],
        summary: 'Nenhuma corrida registrada neste período.',
        status: 'ready',
        generatedAt: new Date().toISOString(),
      };
    }

    const totalDistanceKm = periodRuns.reduce((sum, r) => sum + (r.distanceM / 1000), 0);
    const totalDurationS = periodRuns.reduce((sum, r) => sum + r.durationS, 0);
    const avgBpmValues = periodRuns.map(r => r.avgBpm).filter((b): b is number => typeof b === 'number');
    const maxBpmValues = periodRuns.map(r => r.maxBpm).filter((b): b is number => typeof b === 'number');
    const avgBpm = avgBpmValues.length > 0 ? Math.round(avgBpmValues.reduce((a, b) => a + b, 0) / avgBpmValues.length) : undefined;
    const maxBpm = maxBpmValues.length > 0 ? Math.max(...maxBpmValues) : undefined;

    const knowledgeContext = await formatRunningKnowledgeContext(
      `periodo corrida ${totalDistanceKm.toFixed(1)}km ${Math.floor(totalDurationS / 60)}min`,
      3,
    );

    const prompt = `Analise este período de treino:
- Quantidade de corridas: ${periodRuns.length}
- Distância total: ${totalDistanceKm.toFixed(2)}km
- Duração total: ${Math.floor(totalDurationS / 60)} minutos (${Math.floor((totalDurationS % 60))}s)
${avgBpm ? `- BPM médio: ${avgBpm}` : ''}
${maxBpm ? `- BPM máximo: ${maxBpm}` : ''}

Baseado nestas corridas, dê um feedback de personal trainer com: (1) avaliação do desempenho do período, (2) pontos de melhoria, (3) sugestão para próximo período.

Datas das corridas:
${periodRuns.map(r => `- ${new Date(r.createdAt).toLocaleDateString('pt-BR')}: ${(r.distanceM / 1000).toFixed(2)}km em ${Math.floor(r.durationS / 60)}min`).join('\n')}

Base de conhecimento:
${knowledgeContext}`;

    try {
      const summary = await this.llm.generate(prompt, { systemPrompt: SYSTEM_PROMPT, maxTokens: 400 });

      const runsData: PeriodAnalysisRun[] = periodRuns.map(r => ({
        id: r.id,
        distanceM: r.distanceM,
        durationS: r.durationS,
        avgPace: r.avgPace,
        avgBpm: r.avgBpm,
        maxBpm: r.maxBpm,
        type: r.type,
        date: new Date(r.createdAt).toISOString(),
      }));

      return {
        userId,
        runs: runsData,
        summary,
        status: 'ready',
        generatedAt: new Date().toISOString(),
      };
    } catch (err) {
      logger.error('coach.period-analysis.failed', { userId, err });
      throw err;
    }
  }
}
