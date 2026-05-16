import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
import { CoachPersonaId, DEFAULT_PERSONAS } from './persona/defaults';
import { PromptId, PromptSource } from './versions';

import { PLAN_INIT_DEFAULTS } from './defaults/plan-init.default';
import { PLAN_REVISION_DEFAULTS } from './defaults/plan-revision.default';
import { LIVE_COACH_DEFAULTS } from './defaults/live-coach.default';
import { POST_RUN_REPORT_DEFAULTS } from './defaults/post-run-report.default';
import { PERIOD_ANALYSIS_DEFAULTS } from './defaults/period-analysis.default';
import { COACH_CHAT_DEFAULTS } from './defaults/coach-chat.default';
import { EXAM_ANALYSIS_DEFAULTS } from './defaults/exam-analysis.default';

export interface PromptConfig {
  systemPrompt: string;
  userTemplate: string;
  temperature: number;
  maxTokens: number;
  ragChunks: number;
}

export interface DecisionKnobs {
  respectMessageFrequency: boolean;
  respectFeedbackToggles: boolean;
  respectDndWindow: boolean;
}

export interface PromptsDoc {
  personas?: Partial<Record<CoachPersonaId, { description?: string; updatedAt?: string }>>;
  prompts?: Partial<Record<PromptId, Partial<PromptConfig>>>;
  knobs?: { decisionLayer?: Partial<DecisionKnobs> };
  updatedAt?: string;
  updatedByUid?: string;
  updatedByEmail?: string;
}

export const DEFAULT_KNOBS: DecisionKnobs = {
  respectMessageFrequency: true,
  respectFeedbackToggles: true,
  respectDndWindow: true,
};

const DEFAULTS_BY_ID: Record<PromptId, PromptConfig> = {
  'plan-init': PLAN_INIT_DEFAULTS,
  'plan-revision': PLAN_REVISION_DEFAULTS,
  'live-coach': LIVE_COACH_DEFAULTS,
  'post-run-report': POST_RUN_REPORT_DEFAULTS,
  'period-analysis': PERIOD_ANALYSIS_DEFAULTS,
  'coach-chat': COACH_CHAT_DEFAULTS,
  'exam-analysis': EXAM_ANALYSIS_DEFAULTS,
};

const CACHE_TTL_MS = 60_000;
let cached: { doc: PromptsDoc; loadedAt: number } | null = null;

async function loadDoc(): Promise<PromptsDoc> {
  const now = Date.now();
  if (cached && now - cached.loadedAt < CACHE_TTL_MS) return cached.doc;

  try {
    const snap = await getFirestore().collection('app_config').doc('prompts').get();
    const doc = snap.exists ? (snap.data() as PromptsDoc) : {};
    cached = { doc, loadedAt: now };
    return doc;
  } catch (err) {
    logger.warn('prompts.config_store.load_failed', {
      err: err instanceof Error ? err.message : String(err),
    });
    return cached?.doc ?? {};
  }
}

export async function getPromptConfig(id: PromptId): Promise<{ config: PromptConfig; source: PromptSource }> {
  const doc = await loadDoc();
  const override = doc.prompts?.[id];
  const fallback = DEFAULTS_BY_ID[id];

  if (override && (override.systemPrompt || override.userTemplate)) {
    return {
      config: {
        systemPrompt: override.systemPrompt ?? fallback.systemPrompt,
        userTemplate: override.userTemplate ?? fallback.userTemplate,
        temperature: override.temperature ?? fallback.temperature,
        maxTokens: override.maxTokens ?? fallback.maxTokens,
        ragChunks: override.ragChunks ?? fallback.ragChunks,
      },
      source: 'firestore',
    };
  }

  return { config: fallback, source: 'default' };
}

export async function getPersonaDescription(id: string | undefined | null): Promise<string> {
  const doc = await loadDoc();
  const key = (id as CoachPersonaId) ?? 'motivador';
  const override = doc.personas?.[key]?.description;
  if (override && override.trim().length > 0) return override;
  return (DEFAULT_PERSONAS[key] ?? DEFAULT_PERSONAS.motivador).description;
}

export async function getKnobs(): Promise<DecisionKnobs> {
  const doc = await loadDoc();
  const ov = doc.knobs?.decisionLayer ?? {};
  return {
    respectMessageFrequency: ov.respectMessageFrequency ?? DEFAULT_KNOBS.respectMessageFrequency,
    respectFeedbackToggles: ov.respectFeedbackToggles ?? DEFAULT_KNOBS.respectFeedbackToggles,
    respectDndWindow: ov.respectDndWindow ?? DEFAULT_KNOBS.respectDndWindow,
  };
}

export function invalidatePromptsCache(): void {
  cached = null;
}

export function getDefaultsSnapshot(): {
  personas: typeof DEFAULT_PERSONAS;
  prompts: Record<PromptId, PromptConfig>;
  knobs: DecisionKnobs;
} {
  return { personas: DEFAULT_PERSONAS, prompts: DEFAULTS_BY_ID, knobs: DEFAULT_KNOBS };
}
