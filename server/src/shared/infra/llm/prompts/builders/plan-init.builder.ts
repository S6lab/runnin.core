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

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    input: args.input,
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
