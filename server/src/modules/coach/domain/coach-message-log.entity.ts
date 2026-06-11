/**
 * Persisted coach message — saved each time CoachMessageUseCase generates a cue.
 * Stored in Firestore at `runs/{runId}/coach_messages/{cueId}`.
 *
 * Allows the "VER CONVERSA COM COACH" view (HIST > run detail) to replay the
 * conversation that happened during a specific run.
 */
// Os 8 eventos canônicos (migração s6-ai, 16→8). Docs históricos no
// Firestore podem carregar valores legados (check_in, segment_*, etc) —
// replay lê como string, sem validação runtime, então não quebra.
export type CoachMessageEvent =
  | 'start'
  | 'half_km'
  | 'km_reached'
  | 'bpm_alert'
  | 'pace_alert'
  | 'goal_reached'
  | 'finish'
  | 'no_movement';

export type CoachMessageAuthor = 'coach' | 'user';

export interface CoachMessageLog {
  id: string;
  runId: string;
  userId: string;
  author: CoachMessageAuthor;
  event?: CoachMessageEvent;  // only set when author === 'coach'
  text: string;
  audioMimeType?: string;
  audioBase64Url?: string;    // optional cached audio url (for replay)
  kmAtTime?: number;          // distância acumulada ao gerar
  paceAtTime?: string;        // pace ao gerar
  bpmAtTime?: number;         // bpm ao gerar
  promptVersion?: string;     // ex: 'live-coach.v1.2026-05' ou '...+admin-override'
  /**
   * Origem do texto do cue. firestore/env/default vêm do config-store de
   * prompts (caminho LLM). template:vN indica que o cue foi gerado por
   * `template-cues.ts` na variação N (sem custo LLM).
   */
  promptSource?: 'firestore' | 'env' | 'default' | `template:v${number}`;
  createdAt: string;
  liveTurn?: boolean;         // true when emitido pela sessão Gemini Live nativa
  sessionGeneration?: number; // contador de rotações da sessão Live dentro da mesma run
}
