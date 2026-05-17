import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PlanInitBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  input: { goal: string; level: string; frequency: number; weeksCount: number };
  ragContext: string;
}

export async function buildPlanInitPrompt(args: PlanInitBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('plan-init');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const now = new Date();
  const dowNames = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  const dow = now.getDay() || 7; // 0=Sun → 7
  const today = {
    dayOfWeek: dow,
    weekday: dowNames[dow],
    dateLabel: `${String(now.getDate()).padStart(2, '0')}/${String(now.getMonth() + 1).padStart(2, '0')}/${now.getFullYear()}`,
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
