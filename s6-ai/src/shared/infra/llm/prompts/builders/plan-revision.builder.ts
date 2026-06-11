import { UserProfile } from '@modules/users/domain/user.entity';
import { Plan } from '@modules/plans/domain/plan.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PlanRevisionBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  plan: Pick<Plan, 'goal' | 'level' | 'weeksCount' | 'weeks' | 'adjustedWeeks' | 'raceDate' | 'raceDayOfWeek'>;
  revision: { type: string; subOption?: string; freeText?: string };
  /** Semana corrente (1-based). Revisão só pode mexer em currentWeekNumber+1 e +2. */
  currentWeekNumber?: number;
  /** Volume planejado vs. executado da semana que acabou — usado pelo prompt
   *  pra detectar over/underperformance e ajustar conforme regra anti-fadiga. */
  performance?: {
    plannedKm?: number;
    actualKm?: number;
    deltaPct?: number;
  };
  ragContext: string;
}

export async function buildPlanRevisionPrompt(args: PlanRevisionBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('plan-revision');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const isRace = !!args.plan.raceDate && !!args.plan.raceDayOfWeek;
  const currentWeek = args.currentWeekNumber ?? 0;
  const raceWeekNumber = args.plan.weeksCount;
  const taperWeekNumber = raceWeekNumber - 1;
  const revisableWeeks = [currentWeek + 1, currentWeek + 2].filter(w => w >= 1 && w <= raceWeekNumber);
  const dowName = args.plan.raceDayOfWeek
    ? ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'][args.plan.raceDayOfWeek]
    : '';

  // Bloco de instrução RACE-anchor: só aplica quando o plano tem raceDate.
  // Vai num campo `raceAnchor.context` que o template renderiza no userTemplate.
  let raceAnchorContext = '';
  if (isRace) {
    const fmt = (() => {
      const [y, m, d] = args.plan.raceDate!.split('-');
      return `${d}/${m}/${y}`;
    })();
    const perfDelta = args.performance?.deltaPct;
    const antiOvertraining = perfDelta != null && perfDelta > 15
      ? `- DETECÇÃO: atleta está ${perfDelta.toFixed(0)}% ACIMA do planejado. NÃO suba carga — MANTÉM ou REDUZA 5-10%. Objetivo é chegar fresco na prova, não maximizar treino no meio do mesociclo.`
      : perfDelta != null && perfDelta < -15
        ? `- DETECÇÃO: atleta está ${Math.abs(perfDelta).toFixed(0)}% ABAIXO do planejado. Ajuste pra cima com cautela, mas RESPEITE a curva original — não compense adicionando carga próximo do taper.`
        : `- Performance dentro do esperado. Mantenha progressão padrão na janela revisável.`;
    raceAnchorContext = [
      'ÂNCORA DA PROVA — IMUTÁVEL:',
      `- Prova: ${fmt} (semana ${raceWeekNumber}, dia ${args.plan.raceDayOfWeek} = ${dowName}).`,
      `- weeksCount permanece ${args.plan.weeksCount}. NÃO adicione, remova ou reordene semanas.`,
      `- Race week (${raceWeekNumber}) e Taper week (${taperWeekNumber}) são INTOCÁVEIS — NÃO devolva essas semanas em \`newWeeks\`.`,
      `- Modifique APENAS as semanas ${revisableWeeks.join(' e ')} (janela de revisão).`,
      '',
      'ANTI-FADIGA (objetivo é chegar fresco na prova):',
      antiOvertraining,
      `- Se está dentro do esperado, segue progressão original — não tente acelerar pra "ganhar tempo".`,
    ].join('\n');
  }

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    plan: {
      goal: args.plan.goal,
      level: args.plan.level,
      weeksCount: args.plan.weeksCount,
      // Manda o estado VIGENTE (com ajustes) pro LLM trabalhar em cima
      // do que está sendo executado, não da base intocada.
      weeksJson: JSON.stringify(args.plan.adjustedWeeks ?? args.plan.weeks),
      raceDate: args.plan.raceDate ?? '',
      raceDayOfWeek: args.plan.raceDayOfWeek ?? '',
    },
    revision: {
      type: args.revision.type,
      subOption: args.revision.subOption ?? '',
      freeText: args.revision.freeText ?? '',
    },
    raceAnchor: { context: raceAnchorContext },
    rag: args.ragContext,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('plan-revision', source),
    source,
  };
}
