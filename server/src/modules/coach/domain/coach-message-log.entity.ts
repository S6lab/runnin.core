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
  | 'pace_alert'
  | 'bpm_alert'
  | 'finish'
  | 'question'
  | 'preview';

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
  createdAt: string;
}
