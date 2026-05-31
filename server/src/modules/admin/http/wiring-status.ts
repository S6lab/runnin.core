/**
 * Snapshot do wiring de cada superfície editável do admin:
 *  - prompts: existe override em Firestore? quando foi a última edição?
 *  - personas: idem
 *  - knobs: idem
 *  - roteiroTemplates: idem
 *
 * App admin usa pra renderizar badge "ATIVO / EM CACHE 60s / USANDO DEFAULT"
 * em cada card. Cada item carrega também a referência ao consumer real e o
 * cache TTL pra UI mostrar contagem regressiva.
 */

import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
import { PROMPTS_REGISTRY } from './admin-registries';

const PROMPTS_CACHE_TTL_SEC = 60;
const ROTEIRO_CACHE_TTL_SEC = 60;

export interface OverrideStatus {
  hasOverride: boolean;
  overrideAt?: string;
  consumer: string;
  cacheKey: string;
  cacheTtlSec: number;
}

export interface WiringStatusPayload {
  prompts: Record<string, OverrideStatus>;
  personas: Record<string, OverrideStatus>;
  knobs: Record<string, OverrideStatus>;
  roteiroTemplates: OverrideStatus;
  feedbackToggleWiring: 'wired' | 'phantom';
}

const PROMPT_CONSUMER_BY_ID: Record<string, string> = {
  'plan-init': 'buildPlanInitPrompt (server/.../builders/plan-init.builder.ts)',
  'plan-revision': 'buildPlanRevisionPrompt (server/.../builders/plan-revision.builder.ts)',
  'live-coach': 'buildLiveCoachPrompt (server/.../builders/live-coach.builder.ts)',
  'live-voice': '(deprecated)',
  'post-run-report': 'buildPostRunReportPrompt (server/.../builders/post-run-report.builder.ts)',
  'post-run-report-enriched': 'buildPostRunReportEnrichedPrompt (server/.../builders/post-run-report-enriched.builder.ts)',
  'period-analysis': 'buildPeriodAnalysisPrompt (server/.../builders/period-analysis.builder.ts)',
  'weekly-report': '(deprecated) generateWeeklyReport',
  'coach-chat': 'buildCoachChatPrompt (server/.../builders/coach-chat.builder.ts)',
  'exam-analysis': 'buildExamAnalysisPrompt (server/.../builders/exam-analysis.builder.ts)',
};

const KNOB_CONSUMER: Record<string, string> = {
  respectMessageFrequency: 'applyDecisionLayer (server/.../coach-message.use-case.ts:396)',
  respectFeedbackToggles: 'formatFeedbackFlags (server/.../profile-context.ts)',
  respectDndWindow: 'applyDecisionLayer (server/.../coach-message.use-case.ts:416)',
};

const PERSONA_IDS = ['motivador', 'tecnico'];

export async function getWiringStatus(): Promise<WiringStatusPayload> {
  const db = getFirestore();
  let promptsDoc: any = {};
  let roteiroDoc: any = {};
  try {
    const [pSnap, rSnap] = await Promise.all([
      db.collection('app_config').doc('prompts').get(),
      db.collection('app_config').doc('roteiro_templates').get(),
    ]);
    if (pSnap.exists) promptsDoc = pSnap.data() ?? {};
    if (rSnap.exists) roteiroDoc = rSnap.data() ?? {};
  } catch (err) {
    logger.warn('admin.wiring_status.load_failed', {
      err: err instanceof Error ? err.message : String(err),
    });
  }

  const promptOverrides: Record<string, Partial<{ systemPrompt: string; userTemplate: string; updatedAt: string }>> =
    promptsDoc.prompts ?? {};
  const personaOverrides: Record<string, { description?: string; updatedAt?: string }> =
    promptsDoc.personas ?? {};
  const knobsOverrides: Partial<Record<string, boolean>> = promptsDoc.knobs?.decisionLayer ?? {};
  const lastUpdatedAt: string | undefined = promptsDoc.updatedAt;
  const roteiroUpdatedAt: string | undefined = roteiroDoc.updatedAt;
  const hasRoteiroOverride = !!(roteiroDoc.templates && Object.keys(roteiroDoc.templates).length > 0);

  const prompts: Record<string, OverrideStatus> = {};
  for (const entry of PROMPTS_REGISTRY) {
    const ov = promptOverrides[entry.id];
    const has = !!(ov && (ov.systemPrompt || ov.userTemplate));
    prompts[entry.id] = {
      hasOverride: has,
      overrideAt: has ? lastUpdatedAt : undefined,
      consumer: PROMPT_CONSUMER_BY_ID[entry.id] ?? 'desconhecido',
      cacheKey: entry.id,
      cacheTtlSec: PROMPTS_CACHE_TTL_SEC,
    };
  }

  const personas: Record<string, OverrideStatus> = {};
  for (const id of PERSONA_IDS) {
    const ov = personaOverrides[id];
    const has = !!(ov && ov.description);
    personas[id] = {
      hasOverride: has,
      overrideAt: has ? (ov?.updatedAt ?? lastUpdatedAt) : undefined,
      consumer: 'resolvePersonaTone (server/.../persona/resolver.ts) — usado por 10 lugares',
      cacheKey: `persona:${id}`,
      cacheTtlSec: PROMPTS_CACHE_TTL_SEC,
    };
  }

  const knobs: Record<string, OverrideStatus> = {};
  for (const k of ['respectMessageFrequency', 'respectFeedbackToggles', 'respectDndWindow']) {
    const has = knobsOverrides[k] !== undefined;
    knobs[k] = {
      hasOverride: has,
      overrideAt: has ? lastUpdatedAt : undefined,
      consumer: KNOB_CONSUMER[k] ?? 'desconhecido',
      cacheKey: `knob:${k}`,
      cacheTtlSec: PROMPTS_CACHE_TTL_SEC,
    };
  }

  const roteiroTemplates: OverrideStatus = {
    hasOverride: hasRoteiroOverride,
    overrideAt: hasRoteiroOverride ? roteiroUpdatedAt : undefined,
    consumer: 'getRoteiroTemplates() → buildExecutionSegments (server/.../build-execution-segments.ts)',
    cacheKey: 'roteiro_templates',
    cacheTtlSec: ROTEIRO_CACHE_TTL_SEC,
  };

  return {
    prompts,
    personas,
    knobs,
    roteiroTemplates,
    feedbackToggleWiring: 'wired',
  };
}
