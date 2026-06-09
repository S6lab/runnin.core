import type { GeminiLiveSession } from '@shared/infra/llm/gemini-live.service';
import { logger } from '@shared/logger/logger';

/**
 * Registry process-wide das sessões Live abertas — uma por `(uid, runId)`.
 * Permite que `coach-message.use-case.ts` injete texto via WS Gemini Live
 * quando há sessão ativa, em vez de sintetizar áudio HTTP novamente.
 *
 * Benefício latência: cue chega em ~500ms via streaming Live vs 2-3s
 * abrindo nova sessão TTS HTTP por cue. Voz idêntica (Charon).
 *
 * Limitações:
 * - Single process: se Cloud Run roda múltiplas instances e o WS aberto
 *   está em outra instance, miss → fallback HTTP TTS. Aceitável: usuario
 *   só vê latência maior, não regressão.
 * - TTL Gemini Live ~5min: quando sessão fecha por TTL, é removida do
 *   registry automaticamente (`unregister` no onClose do WS handler).
 */

interface RegistryEntry {
  session: GeminiLiveSession;
  uid: string;
  runId: string;
  openedAt: number;
}

const sessions = new Map<string, RegistryEntry>();

function keyFor(uid: string, runId: string): string {
  return `${uid}::${runId}`;
}

/** Registra sessão Live aberta. Chamado pelo WS handler após session.open(). */
export function registerLiveSession(uid: string, runId: string, session: GeminiLiveSession): void {
  const k = keyFor(uid, runId);
  // Sobrescreve entry anterior se existir (rotação/reconnect cliente cria
  // uma session nova mas mesmo runId — a velha já foi fechada).
  sessions.set(k, { session, uid, runId, openedAt: Date.now() });
  logger.info('coach.live.registry.added', { uid, runId, total: sessions.size });
}

/** Remove sessão do registry. Chamado quando WS fecha (cliente ou Gemini). */
export function unregisterLiveSession(uid: string, runId: string): void {
  const k = keyFor(uid, runId);
  if (sessions.delete(k)) {
    logger.info('coach.live.registry.removed', { uid, runId, total: sessions.size });
  }
}

/**
 * Recupera sessão Live ativa pra esse (uid, runId). Retorna null quando
 * não há — caller cai pro caminho HTTP TTS normal.
 */
export function getActiveLiveSession(uid: string, runId: string): GeminiLiveSession | null {
  const entry = sessions.get(keyFor(uid, runId));
  return entry?.session ?? null;
}

/** Estatísticas pra admin/observability. */
export function getRegistryStats(): { total: number; oldest_ms?: number } {
  if (sessions.size === 0) return { total: 0 };
  let oldest = Number.MAX_SAFE_INTEGER;
  for (const e of sessions.values()) {
    if (e.openedAt < oldest) oldest = e.openedAt;
  }
  return { total: sessions.size, oldest_ms: Date.now() - oldest };
}
