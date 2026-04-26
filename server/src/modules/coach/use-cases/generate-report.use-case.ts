import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Run } from '@modules/runs/domain/run.entity';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin. Gere análises técnicas de corrida em português brasileiro.
Seja específico com dados reais fornecidos. Máximo 3 parágrafos curtos. Sem emojis. Tom profissional.`;

export class GenerateReportUseCase {
  private llm = getAsyncLLM();

  async execute(run: Run, userId: string): Promise<string> {
    const dist = (run.distanceM / 1000).toFixed(2);
    const minutes = Math.floor(run.durationS / 60);
    const knowledgeContext = formatRunningKnowledgeContext(
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

Dê um relatório técnico com: (1) avaliação do desempenho, (2) pontos de melhoria, (3) sugestão para próxima sessão.

Base de conhecimento:
${knowledgeContext}`;

    try {
      const summary = await this.llm.generate(prompt, { systemPrompt: SYSTEM_PROMPT, maxTokens: 400 });

      // Salva o relatório no Firestore
      const reportId = run.id;
      await getFirestore()
        .collection(`users/${userId}/runs/${run.id}/reports`)
        .doc(reportId)
        .set({ summary, generatedAt: new Date().toISOString(), status: 'ready' });

      // Atualiza a run com o reportId
      await getFirestore()
        .collection(`users/${userId}/runs`)
        .doc(run.id)
        .update({ coachReportId: reportId });

      return reportId;
    } catch (err) {
      logger.error('coach.report.failed', { runId: run.id, err });
      throw err;
    }
  }
}
