export const PROMPT_VERSIONS = {
  'plan-init': 'v2.2026-05',
  'plan-revision': 'v2.2026-05',
  'live-coach': 'v2.2026-05',
  'live-voice': 'v1.2026-05',
  'post-run-report': 'v2.2026-05',
  'post-run-report-enriched': 'v2.2026-05',
  'period-analysis': 'v2.2026-05',
  'weekly-report': 'v1.2026-05',
  'coach-chat': 'v2.2026-05',
  'exam-analysis': 'v2.2026-05',
} as const;

export type PromptId = keyof typeof PROMPT_VERSIONS;

export type PromptSource = 'firestore' | 'env' | 'default';

export function stampVersion(id: PromptId, source: PromptSource): string {
  const base = PROMPT_VERSIONS[id];
  return source === 'firestore' ? `${id}.${base}+admin-override` : `${id}.${base}`;
}
