/**
 * Persisted coach message — saved each time CoachMessageUseCase generates a cue.
 * Stored in Firestore at `runs/{runId}/coach_messages/{cueId}`.
 *
 * Allows the "VER CONVERSA COM COACH" view (HIST > run detail) to replay the
 * conversation that happened during a specific run.
 */
export type CoachMessageEvent =
  | 'pre_run'
  | 'start'
  | 'km_reached'
  | 'km_split'
  | 'pace_alert'
  | 'high_bpm'
  | 'motivation'
  | 'finish'
  | 'question'
  | 'preview'
  | 'segment_start'
  | 'segment_pace_off'
  | 'segment_end'
  | 'goal_reached'
  | 'check_in'
  | 'push_to_talk';

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
  promptSource?: 'firestore' | 'env' | 'default';
  createdAt: string;
  liveTurn?: boolean;         // true when emitido pela sessão Gemini Live nativa
  sessionGeneration?: number; // contador de rotações da sessão Live dentro da mesma run
}
