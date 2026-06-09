import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
import { computeCostUsd } from './llm-pricing';
import { FieldValue } from 'firebase-admin/firestore';

/**
 * Tracker centralizado de uso LLM. Chamado por cada adapter (gemini, together,
 * groq, multimodal) imediatamente após o logger.info do call.
 *
 * Persiste agregado por user-dia em Firestore:
 *   users/{uid}/llm_usage/{YYYY-MM-DD}
 *
 * Crons / sistema (userId === null) vão em:
 *   system/llm_usage/{YYYY-MM-DD}
 *
 * Doc id = data ISO → 1 doc/dia/user. FieldValue.increment garante atomic
 * sem race condition em chamadas paralelas.
 *
 * Best-effort: erro silencioso. Tracking não pode quebrar fluxo principal.
 */
export interface TrackUsageInput {
  /** uid do user que disparou. Null em CRON jobs/system tasks. */
  userId: string | null;
  /** Nome do modelo (deve bater com chave em LLM_PRICING_USD_PER_1M). */
  model: string;
  /** Tag do use case que disparou ('generate-plan', 'live-coach',
   *  'weekly-report', 'analyze-exam', 'coach-message', 'narratives'). */
  useCase: string;
  /** Tokens de input (prompt). */
  promptTokens: number;
  /** Tokens de output (resposta do LLM). */
  outputTokens: number;
  /** Latência ms da chamada (pra dashboards de saúde). */
  latencyMs?: number;
}

const _systemBucket = 'system';

export async function trackLlmUsage(input: TrackUsageInput): Promise<void> {
  try {
    const { userId, model, useCase, promptTokens, outputTokens } = input;
    const totalTokens = promptTokens + outputTokens;
    if (totalTokens <= 0) return;
    const costUsd = computeCostUsd(model, promptTokens, outputTokens);
    const date = new Date().toISOString().slice(0, 10);
    const db = getFirestore();
    // Path: users/{uid}/llm_usage/{date}  OR  system/llm_usage/{date}
    const docRef = userId
      ? db.collection('users').doc(userId).collection('llm_usage').doc(date)
      : db.collection(_systemBucket).doc('llm_usage').collection('daily').doc(date);

    await docRef.set(
      {
        date,
        totalInputTokens: FieldValue.increment(promptTokens),
        totalOutputTokens: FieldValue.increment(outputTokens),
        totalCalls: FieldValue.increment(1),
        totalCostUsd: FieldValue.increment(costUsd),
        byModel: {
          [model]: {
            input: FieldValue.increment(promptTokens),
            output: FieldValue.increment(outputTokens),
            calls: FieldValue.increment(1),
            costUsd: FieldValue.increment(costUsd),
          },
        },
        byUseCase: {
          [useCase]: {
            calls: FieldValue.increment(1),
            costUsd: FieldValue.increment(costUsd),
          },
        },
        updatedAt: new Date().toISOString(),
      },
      { merge: true },
    );
    logger.info('llm.usage.tracked', {
      userId: userId ?? 'system',
      model,
      useCase,
      promptTokens,
      outputTokens,
      costUsd,
      latencyMs: input.latencyMs,
    });
  } catch (err) {
    logger.warn('llm.usage.tracked_failed', {
      err: err instanceof Error ? err.message : String(err),
    });
  }
}
