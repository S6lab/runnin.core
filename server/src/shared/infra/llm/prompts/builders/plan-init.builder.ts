import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PlanInitBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  input: {
    goal: string;
    level: string;
    frequency: number;
    weeksCount: number;
    /** D0 escolhida pelo user no onboarding (ISO YYYY-MM-DD). */
    startDate?: string;
    /** Matiz fino do nível dentro de 'iniciante' (vindo da jornada de criação
     *  do plano: nunca_corri | esporadico | iniciante_freq). null se já
     *  cobre o enum direto (intermediario/avancado). */
    levelHint?: string | null;
    /** Volume atual do atleta em km/sem (informado na jornada). */
    currentWeeklyKm?: number | null;
    /** Pace atual confortável "M:SS/km" (informado na jornada). */
    currentPaceMinKm?: string | null;
    /** Dias em que o atleta pode treinar (1=seg…7=dom). [] = sem restrição. */
    availableDays?: number[] | null;
  };
  ragContext: string;
}

export async function buildPlanInitPrompt(args: PlanInitBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('plan-init');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const dowNames = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  // startDate vem do onboarding ("começar hoje" ou "começar dia X"). Sem
  // ela, default = hoje. A semana 1 e a periodização toda começam aqui.
  const startIso = args.input.startDate ?? new Date().toISOString().slice(0, 10);
  const startD = new Date(`${startIso}T00:00:00`);
  const dow = startD.getDay() || 7;
  const endD = new Date(startD.getTime() + (args.input.weeksCount * 7 - 1) * 86_400_000);
  const today = {
    dayOfWeek: dow,
    weekday: dowNames[dow],
    dateLabel: `${String(startD.getDate()).padStart(2, '0')}/${String(startD.getMonth() + 1).padStart(2, '0')}/${startD.getFullYear()}`,
    endDateLabel: `${String(endD.getDate()).padStart(2, '0')}/${String(endD.getMonth() + 1).padStart(2, '0')}/${endD.getFullYear()}`,
  };

  // Bloco extra de contexto da jornada nova de criação do plano: matiz fino
  // do nível, volume/pace atuais, dias disponíveis, e tratamento especial pro
  // objetivo "Flow". Montamos um único parágrafo em `journey.context` que vai
  // no userTemplate — string vazia quando não há nada a comunicar, sem inflar
  // o prompt.
  const dayNamesShort = ['', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  const goalNorm = (args.input.goal ?? '').toLowerCase();
  const isFlow = goalNorm === 'flow' || goalNorm.includes('flow');
  const journeyLines: string[] = [];
  if (args.input.levelHint) {
    const hintLabel =
      args.input.levelHint === 'nunca_corri'
        ? 'NUNCA correu antes — começar com walk-run conservador, foco em criar o hábito.'
        : args.input.levelHint === 'esporadico'
          ? 'Corre esporadicamente (1-2x/sem sem regularidade) — base aeróbica frágil, sem qualidade nas 3 primeiras semanas.'
          : 'Já corre com alguma frequência — pode aceitar 1 qualidade leve a partir da semana 2.';
    journeyLines.push(`Matiz do nível (refinamento dentro de "iniciante"): ${hintLabel}`);
  }
  if (typeof args.input.currentWeeklyKm === 'number' && args.input.currentWeeklyKm > 0) {
    journeyLines.push(`Volume atual auto-reportado: ~${args.input.currentWeeklyKm} km/sem — calibre a semana 1 NUNCA acima desse valor + 10%.`);
  }
  if (args.input.currentPaceMinKm) {
    journeyLines.push(`Pace confortável auto-reportado: ${args.input.currentPaceMinKm}/km — use como referência pro Easy Run (não acelere acima).`);
  }
  const days = args.input.availableDays ?? [];
  if (days.length > 0) {
    const label = days.map((d) => dayNamesShort[d] ?? '').filter(Boolean).join(', ');
    journeyLines.push(
      `Dias disponíveis pra treinar (HARD CONSTRAINT): ${label}. Distribua as sessões SOMENTE nestes dias. Se frequency (${args.input.frequency}) for menor que esses dias, escolha os melhores; se for maior, mantenha frequency = ${days.length}.`,
    );
  }
  if (isFlow) {
    journeyLines.push(
      'Objetivo FLOW ("você contra você mesmo"): SEM meta de distância/pace específica. Construa um bloco de melhoria contínua com incrementos graduais (+5-10% volume/semana). Pace conversável (zona 1-2) na maioria das corridas. Os checkpoints semanais propõem evoluções — não force pace alvo agressivo aqui.',
    );
  }
  const journey = {
    context: journeyLines.length === 0 ? '' : `CONTEXTO DA JORNADA DE CRIAÇÃO DO PLANO (sobrepõe defaults do perfil):\n- ${journeyLines.join('\n- ')}`,
  };

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    input: args.input,
    journey,
    rag: args.ragContext,
    today,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('plan-init', source),
    source,
  };
}
