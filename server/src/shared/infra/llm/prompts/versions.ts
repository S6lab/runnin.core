export const PROMPT_VERSIONS = {
  'plan-init': 'v1.2026-05',
  'plan-revision': 'v1.2026-05',
  'live-coach': 'v1.2026-05',
  'post-run-report': 'v1.2026-05',
  'period-analysis': 'v1.2026-05',
  'coach-chat': 'v1.2026-05',
  'exam-analysis': 'v1.2026-05',
} as const;

export type PromptId = keyof typeof PROMPT_VERSIONS;

export type PromptSource = 'firestore' | 'env' | 'default';

export function stampVersion(id: PromptId, source: PromptSource): string {
  const base = PROMPT_VERSIONS[id];
  return source === 'firestore' ? `${id}.${base}+admin-override` : `${id}.${base}`;
}
