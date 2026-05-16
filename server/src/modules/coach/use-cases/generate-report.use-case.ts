import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { buildPostRunReportPrompt } from '@shared/infra/llm/prompts';
import { CoachReportRepository } from '../domain/coach-report.repository';
import { CoachRuntimeContextService } from './coach-runtime-context.service';

export class GenerateReportUseCase {
  private llm = getAsyncLLM();
  private runtime = new CoachRuntimeContextService();

  constructor(
    private readonly reports: CoachReportRepository,
    private readonly runs: RunRepository,
  ) {}

  async execute(run: Run, userId: string): Promise<string> {
    const dist = (run.distanceM / 1000).toFixed(2);
    const minutes = Math.floor(run.durationS / 60);
    const runtime = await this.runtime.getContext(userId);

    const knowledgeContext = await formatRunningKnowledgeContext(
      `${run.type} corrida ${dist}km pace ${run.avgPace ?? ''} bpm ${run.avgBpm ?? ''}`,
      3,
    );

    const summaryLines = [
      `- Tipo: ${run.type}`,
      `- Distância: ${dist}km`,
      `- Duração: ${minutes} minutos`,
      `- Pace médio: ${run.avgPace ?? 'N/A'}/km`,
      `- BPM médio: ${run.avgBpm ?? 'N/A'}`,
      `- BPM máximo: ${run.maxBpm ?? 'N/A'}`,
    ];
    if (run.targetPace) summaryLines.push(`- Pace alvo: ${run.targetPace}/km`);

    const planContext = runtime.currentPlan
      ? `Plano: ${runtime.currentPlan.goal} (${runtime.currentPlan.level}, semana atual ${runtime.currentPlan.currentWeek?.weekNumber ?? 'N/A'})`
      : 'Sem plano ativo.';

    const recentRunsContext = runtime.recentRuns
      .slice(0, 5)
      .map(r => `${r.type} ${r.distanceKm}km em ${r.durationMin}min`)
      .join('; ') || 'Sem corridas recentes.';

    const built = await buildPostRunReportPrompt({
      profile: runtime.profile,
      run: { summary: summaryLines.join('\n') },
      planContext,
      recentRunsContext,
      ragContext: knowledgeContext,
    });

    try {
      const summary = await this.llm.generate(built.userPrompt, {
        systemPrompt: built.systemPrompt,
        maxTokens: built.maxTokens,
        temperature: built.temperature,
      });
      const reportId = run.id;

      await this.reports.save({
        runId: reportId,
        userId,
        summary,
        status: 'ready',
        generatedAt: new Date().toISOString(),
      });

      await this.runs.update(run.id, userId, { coachReportId: reportId });

      logger.info('coach.report.generated', { runId: run.id, version: built.version, source: built.source });
      return reportId;
    } catch (err) {
      logger.error('coach.report.failed', { runId: run.id, err });
      throw err;
    }
  }
}
