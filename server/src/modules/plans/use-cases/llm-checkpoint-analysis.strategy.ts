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
          .map((r) => {
            const head =
              `- ${r.date}: ${r.distanceKm.toFixed(1)}km em ${Math.round(r.durationS / 60)}min` +
              `${r.avgPace ? `, pace ${r.avgPace}` : ''}` +
              `${r.avgBpm ? `, BPM méd ${r.avgBpm}` : ''}`;
            if (!r.userFeedback || r.userFeedback.length === 0) return head;
            const fb = r.userFeedback
              .map((i) => `${i.type}${i.note ? ` (${i.note})` : ''}`)
              .join(', ');
            return `${head}\n  feedback do user: ${fb}`;
          })
          .join('\n')
      : '(nenhuma corrida concluída na semana)';

    const followingDigest = followingWeeks
      .map(
        (w) =>
          `Semana ${w.weekNumber}: ${w.sessions.length} sessões / ${w.sessions
            .reduce((s, x) => s + x.distanceKm, 0)
            .toFixed(1)}km (${w.detailLevel ?? 'full'})`,
      )
      .join('\n');

    // As 2 PRÓXIMAS semanas são DETALHADAS neste checkpoint (esqueleto→full).
    // As demais seguem esqueleto, com volume/pace ajustados.
    const detailWeeks = followingWeeks.slice(0, 2);
    const detailWeekNums = detailWeeks.map((w) => w.weekNumber).join(' e ');
    const skeletonWeekNums = followingWeeks
      .slice(2)
      .map((w) => w.weekNumber)
      .join(', ');

    // ─── RACE anchor block (só em planos RACE com raceDate) ──────────────
    // Mesmo recebendo a instrução, o LLM pode tentar mexer na race week ou
    // subir carga próximo dela. enforceRevisionInvariants (no apply) repara
    // se ele violar — esse bloco é o primeiro line of defense.
    const isRace = !!plan.raceDate && !!plan.raceDayOfWeek;
    const raceWeekNumber = plan.weeksCount;
    const taperWeekNumber = raceWeekNumber - 1;
    const deltaPct = weekMetrics.plannedDistanceKm > 0
      ? ((weekMetrics.actualDistanceKm - weekMetrics.plannedDistanceKm) / weekMetrics.plannedDistanceKm) * 100
      : 0;
    let raceAnchorBlock = '';
    if (isRace) {
      const dowName = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'][plan.raceDayOfWeek!];
      const [y, m, d] = plan.raceDate!.split('-');
      const antiFatigue = deltaPct > 15
        ? `- DETECÇÃO: atleta está ${deltaPct.toFixed(0)}% ACIMA do volume planejado nesta semana. NÃO suba carga nas próximas semanas — MANTÉM ou REDUZA 5-10%. Objetivo é chegar fresco na prova (semana ${raceWeekNumber}), não maximizar treino no meio do mesociclo. Cite essa leitura no coachExplanation com o aviso "vamos preservar pra você chegar inteiro na prova".`
        : deltaPct < -15
          ? `- DETECÇÃO: atleta está ${Math.abs(deltaPct).toFixed(0)}% ABAIXO do volume planejado. Ajuste pra cima com cautela, mas RESPEITE a curva do plano — nada de "recuperar carga perdida" próximo do taper (semana ${taperWeekNumber}).`
          : `- Performance dentro do esperado. Progressão padrão na janela revisável.`;
      raceAnchorBlock = [
        '',
        'ÂNCORA DA PROVA — REGRA DURA IMUTÁVEL:',
        `- Prova: ${d}/${m}/${y} (semana ${raceWeekNumber}, dia ${plan.raceDayOfWeek} = ${dowName}).`,
        `- weeksCount permanece ${plan.weeksCount}. NÃO adicione/remova semanas.`,
        `- Race week (${raceWeekNumber}) e Taper week (${taperWeekNumber}) são INTOCÁVEIS — devolva exatamente como estão no plano atual (cópia verbatim no \`newWeeks\`).`,
        `- AJUSTES reais apenas em ${detailWeekNums || `semanas ${weekNumber + 1}+`} (janela de revisão).`,
        '',
        'ANTI-FADIGA (objetivo é chegar inteiro na prova, não brilhar no meio do plano):',
        antiFatigue,
        '',
      ].join('\n');
    }

    const prompt = `Você é o Coach AI do runnin executando um CHECKPOINT semanal.

CONTEXTO DA SEMANA ${weekNumber}:
- Aderência: ${weekMetrics.completedRuns}/${weekMetrics.plannedSessions} sessões (${Math.round(weekMetrics.completionRate * 100)}%)
- Distância: ${weekMetrics.actualDistanceKm.toFixed(1)}km feita / ${weekMetrics.plannedDistanceKm.toFixed(1)}km planejada
${weekMetrics.avgBpm ? `- BPM médio: ${weekMetrics.avgBpm}` : ''}
${weekMetrics.avgPaceMinPerKm ? `- Pace médio: ${weekMetrics.avgPaceMinPerKm.toFixed(2)}min/km` : ''}

CORRIDAS DA SEMANA (cada item pode trazer feedback subjetivo enviado pelo user logo após a corrida — use pra correlacionar chips com a corrida específica):
${runsDigest}

FEEDBACK AGREGADO DA SEMANA (união deduplicada dos chips submetidos em todas as corridas — use como leitura macro):
${inputsDigest}

SEMANAS RESTANTES NO PLANO (você vai ajustar essas):
${followingDigest}
${raceAnchorBlock}
Sua tarefa: avaliar a semana, considerar inputs do usuário e ajustar as semanas SEGUINTES (NÃO mexa em semanas anteriores nem na semana ${weekNumber}). Mantenha estrutura/ID das sessions onde possível; ajuste distanceKm, targetPace, durationMin, type, notes conforme necessário.

REGRA DURA — TIPO DE SESSÃO (igual à criação do plano): o runnin é um app de CORRIDA. As sessões agendadas SÓ podem ser corrida (Easy Run, Intervalado, Tempo Run, Long Run, Recovery, Fartlek, Progressivo, Tiros) ou "Caminhada" (único tipo não-corrida permitido como sessão, pra baixo impacto/base aeróbica/recuperação). NUNCA agende ciclismo/bike, natação, elíptico, remo ou musculação como uma SESSÃO (campo type). Esses cross-trainings podem, no MÁXIMO, ser SUGERIDOS no campo notes como atividade complementar opcional — jamais viram uma sessão do plano.

GERAÇÃO EM DOIS NÍVEIS (CRÍTICO):
- As 2 PRÓXIMAS semanas (${detailWeekNums || 'as imediatamente seguintes'}) devem vir com DETALHE COMPLETO: cada sessão com targetPace, durationMin, hydrationLiters, nutritionPre, nutritionPost e notes ricas (2-4 frases com fase + foco + cuidado). É AGORA que essas semanas ganham detalhe — antes estavam em esqueleto.${skeletonWeekNums ? `\n- As demais semanas (${skeletonWeekNums}) seguem em ESQUELETO: só type, distanceKm, targetPace e notes curta (1 frase). NÃO preencha hydration/nutrition nessas — serão detalhadas no próximo checkpoint.` : ''}
- Seja CRIATIVO e técnico nos tipos de sessão das 2 semanas detalhadas (Fartlek, Progressivo, Tiros, Tempo em blocos) — evite repetir "Easy Run" demais. Toda variação tecnicamente verdadeira.

Princípios:
- "load_up" + boa aderência → suba volume 5-10% nas próximas 2 semanas
- "load_down" / "low_energy" / "sleep_bad" → reduza volume 10-15% na próxima semana, redistribuir intensidade
- "pain" → tira intervalado/tempo da próxima semana, mantém só easy/recovery; mensagem reforça avaliação clínica
- "schedule_conflict" → reduz N de sessões por semana mas mantém km total redistribuído
- aderência baixa (<50%) sem input do user → reduz volume defensivamente; reconheça e adapte
- aderência alta (>90%) sem input → mantém ou progressão padrão (sem aumento extra)
- usuário rodou ALÉM do planejado (distância maior OU pace mais rápido que targetPace) e completou bem (sem dor/exaustão) → considere subir progressão 5-10% (conservador) ao invés de manter; cite no coachExplanation a leitura "você rodou X km/min/km além do plano e tolerou bem"
- PRINCÍPIO GUARDA: seja CONSERVADOR ao SUBIR carga (lesão custa mais que undertraining); seja RESPONSIVO ao REDUZIR carga ao primeiro sinal de sobrecarga/dor/sono ruim

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
