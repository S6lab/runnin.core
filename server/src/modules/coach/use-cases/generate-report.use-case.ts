import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Run } from '@modules/runs/domain/run.entity';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente.
Gere análises técnicas detalhadas de corrida em português brasileiro, falando diretamente com o corredor.
Seja específico com dados reais fornecidos e transforme a análise em orientação prática.
Inclua: (1) avaliação do desempenho geral, (2) análise de zonas cardíacas se disponível,
(3) comparação com o plano esperado, (4) pontos de melhoria, (5) recomendações para recuperação e próxima sessão.
Tom humano, firme e motivador, como feedback pós-treino. Máximo 4-5 parágrafos. Sem emojis.`;

export class GenerateReportUseCase {
  private llm = getAsyncLLM();

  async execute(run: Run, userId: string): Promise<string> {
    const dist = (run.distanceM / 1000).toFixed(2);
    const minutes = Math.floor(run.durationS / 60);
    const knowledgeContext = await formatRunningKnowledgeContext(
      `${run.type} corrida ${dist}km pace ${run.avgPace ?? ''} bpm ${run.avgBpm ?? ''}`,
      3,
    );

    const prompt = `Analise esta corrida em detalhes:

**Dados da sessão:**
- Tipo: ${run.type}
- Distância: ${dist}km
- Duração: ${minutes} minutos
- Pace médio: ${run.avgPace ?? 'N/A'}/km
- BPM médio: ${run.avgBpm ?? 'N/A'}
- BPM máximo: ${run.maxBpm ?? 'N/A'}
${run.targetPace ? `- Pace alvo: ${run.targetPace}/km` : ''}
${run.xpEarned ? `- XP conquistado: ${run.xpEarned}` : ''}

**Análise esperada:**
1. **Desempenho geral**: Como o corredor executou a sessão? Atingiu os objetivos?
2. **Análise de zonas cardíacas**: ${run.avgBpm ? `Com BPM médio de ${run.avgBpm} e máximo de ${run.maxBpm}, como foi a distribuição de esforço? Estava adequado para o tipo ${run.type}?` : 'Dados de frequência cardíaca não disponíveis.'}
3. **Comparação com o plano**: ${run.targetPace ? `O pace alvo era ${run.targetPace}/km e o realizado foi ${run.avgPace ?? 'N/A'}/km. Analise a diferença.` : 'Sem pace alvo definido.'}
4. **Pontos de melhoria**: O que pode ser ajustado na próxima sessão?
5. **Recomendações**: Sugestões para recuperação (hoje/amanhã) e estratégia para a próxima sessão.

Base de conhecimento:
${knowledgeContext}`;

    try {
      const summary = await this.llm.generate(prompt, { systemPrompt: SYSTEM_PROMPT, maxTokens: 600 });

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
