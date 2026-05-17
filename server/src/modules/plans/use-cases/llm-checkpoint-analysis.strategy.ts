import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { PlanWeek } from '../domain/plan.entity';
import {
  CheckpointAnalysisInput,
  CheckpointAnalysisOutput,
  CheckpointAnalysisStrategy,
} from './checkpoint-analysis.strategy';
import { logger } from '@shared/logger/logger';

/**
 * Estratégia default: 1 chamada LLM que combina análise (descritiva)
 * e ajuste do plano (estrutural). Devolve JSON estrito.
 *
 * Fallback se LLM falha ou JSON não parseia:
 *   - autoAnalysis = descrição mecânica das métricas
 *   - newWeeks = [] (sem ajuste estrutural)
 *   - coachExplanation = texto curto reconhecendo a falha
 *
 * Mantém a aplicação progressível mesmo sem LLM disponível.
 */
export class LlmCheckpointAnalysisStrategy
  implements CheckpointAnalysisStrategy
{
  private llm = getAsyncLLM();

  async analyze(input: CheckpointAnalysisInput): Promise<CheckpointAnalysisOutput> {
    const { plan, weekNumber, userInputs, weekRuns, weekMetrics } = input;

    const followingWeeks = plan.weeks.filter((w) => w.weekNumber > weekNumber);
    if (followingWeeks.length === 0) {
      return {
        autoAnalysis: 'Última semana do mesociclo — sem semanas seguintes pra ajustar.',
        newWeeks: [],
        coachExplanation:
          'Esta era a última semana do plano. Nenhum ajuste foi aplicado. '
          + 'Considere gerar um novo plano com base na evolução desta jornada.',
      };
    }

    const inputsDigest = userInputs.length
      ? userInputs
          .map((i) => `- ${i.type}${i.note ? `: ${i.note}` : ''}`)
          .join('\n')
      : '(nenhum input do usuário — só análise objetiva)';

    const runsDigest = weekRuns.length
      ? weekRuns
          .map(
            (r) =>
              `- ${r.date}: ${r.distanceKm.toFixed(1)}km em ${Math.round(r.durationS / 60)}min${
                r.avgPace ? `, pace ${r.avgPace}` : ''
              }${r.avgBpm ? `, BPM méd ${r.avgBpm}` : ''}`,
          )
          .join('\n')
      : '(nenhuma corrida concluída na semana)';

    const followingDigest = followingWeeks
      .map(
        (w) =>
          `Semana ${w.weekNumber}: ${w.sessions.length} sessões / ${w.sessions
            .reduce((s, x) => s + x.distanceKm, 0)
            .toFixed(1)}km`,
      )
      .join('\n');

    const prompt = `Você é o Coach AI do runnin executando um CHECKPOINT semanal.

CONTEXTO DA SEMANA ${weekNumber}:
- Aderência: ${weekMetrics.completedRuns}/${weekMetrics.plannedSessions} sessões (${Math.round(weekMetrics.completionRate * 100)}%)
- Distância: ${weekMetrics.actualDistanceKm.toFixed(1)}km feita / ${weekMetrics.plannedDistanceKm.toFixed(1)}km planejada
${weekMetrics.avgBpm ? `- BPM médio: ${weekMetrics.avgBpm}` : ''}
${weekMetrics.avgPaceMinPerKm ? `- Pace médio: ${weekMetrics.avgPaceMinPerKm.toFixed(2)}min/km` : ''}

CORRIDAS DA SEMANA:
${runsDigest}

INPUTS DO USUÁRIO NO CHECKPOINT:
${inputsDigest}

SEMANAS RESTANTES NO PLANO (você vai ajustar essas):
${followingDigest}

Sua tarefa: avaliar a semana, considerar inputs do usuário e ajustar as semanas SEGUINTES (NÃO mexa em semanas anteriores nem na semana ${weekNumber}). Mantenha estrutura/ID das sessions onde possível; ajuste distanceKm, targetPace, durationMin, type, notes conforme necessário.

Princípios:
- "load_up" + boa aderência → suba volume 5-10% nas próximas 2 semanas
- "load_down" / "low_energy" / "sleep_bad" → reduza volume 10-15% na próxima semana, redistribuir intensidade
- "pain" → tira intervalado/tempo da próxima semana, mantém só easy/recovery; mensagem reforça avaliação clínica
- "schedule_conflict" → reduz N de sessões por semana mas mantém km total redistribuído
- aderência baixa (<50%) sem input do user → reduz volume defensivamente; reconheça e adapte
- aderência alta (>90%) sem input → mantém ou progressão padrão (sem aumento extra)

RESPONDA APENAS JSON estritamente neste schema:

{
  "autoAnalysis": "string (1-3 frases) descrevendo o que você LEU dos dados — não o que vai fazer.",
  "coachExplanation": "string (3-5 parágrafos markdown) explicando os ajustes e o porquê fisiológico/comportamental. Use 'você'. PT-BR.",
  "newWeeks": [
    {
      "weekNumber": ${followingWeeks[0]?.weekNumber ?? weekNumber + 1},
      "sessions": [
        { "dayOfWeek": 1..7, "type": "...", "distanceKm": N, "targetPace": "M:SS"?, "durationMin": N?, "hydrationLiters": N?, "nutritionPre": "..."?, "nutritionPost": "..."?, "notes": "..." }
      ]
    },
    ...
  ]
}

REGRAS:
- newWeeks deve conter EXATAMENTE as semanas restantes (${followingWeeks.length} semanas, de ${followingWeeks[0]?.weekNumber} a ${followingWeeks[followingWeeks.length - 1]?.weekNumber}).
- Sem comentários, sem texto fora do JSON.
- Se nenhum ajuste se justifica, devolva newWeeks copiando as semanas atuais sem mudança E explique no coachExplanation que "mantém-se o plano original porque...".`;

    try {
      const raw = await this.llm.generate(prompt, {
        systemPrompt: 'Você é o Coach AI. Retorne SOMENTE JSON válido. Sem comentários.',
        maxTokens: 8000,
        temperature: 0.35,
      });

      const parsed = this._parseJson(raw);
      if (!parsed) {
        return this._fallback(input, 'JSON inválido do LLM');
      }
      return {
        autoAnalysis: parsed.autoAnalysis ?? this._mechanicalAnalysis(weekMetrics),
        coachExplanation: parsed.coachExplanation ?? 'Ajustes aplicados às semanas seguintes.',
        newWeeks: parsed.newWeeks ?? [],
      };
    } catch (err) {
      logger.warn('checkpoint.analysis.llm_failed', {
        weekNumber,
        err: err instanceof Error ? err.message : String(err),
      });
      return this._fallback(input, 'LLM indisponível');
    }
  }

  private _fallback(
    input: CheckpointAnalysisInput,
    reason: string,
  ): CheckpointAnalysisOutput {
    return {
      autoAnalysis: this._mechanicalAnalysis(input.weekMetrics),
      newWeeks: [],
      coachExplanation:
        `Análise estrutural ficou indisponível neste checkpoint (${reason}). ` +
        'Seu plano segue como estava. Você pode tentar de novo mais tarde ou ' +
        'aguardar o próximo checkpoint semanal.',
    };
  }

  private _mechanicalAnalysis(m: CheckpointAnalysisInput['weekMetrics']): string {
    const pct = Math.round(m.completionRate * 100);
    return (
      `Semana fechou com ${m.completedRuns}/${m.plannedSessions} sessões (${pct}% aderência) ` +
      `e ${m.actualDistanceKm.toFixed(1)}km dos ${m.plannedDistanceKm.toFixed(1)}km planejados.`
    );
  }

  private _parseJson(raw: string): {
    autoAnalysis?: string;
    coachExplanation?: string;
    newWeeks?: PlanWeek[];
  } | null {
    try {
      const cleaned = raw.replace(/^```(?:json)?\s*|\s*```\s*$/g, '').trim();
      const start = cleaned.indexOf('{');
      const end = cleaned.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      const obj = JSON.parse(cleaned.slice(start, end + 1)) as {
        autoAnalysis?: string;
        coachExplanation?: string;
        newWeeks?: PlanWeek[];
      };
      return obj;
    } catch {
      return null;
    }
  }
}
