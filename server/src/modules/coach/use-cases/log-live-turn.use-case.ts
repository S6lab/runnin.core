import { randomUUID } from 'crypto';
import {
  CoachMessageAuthor,
  CoachMessageEvent,
  CoachMessageLog,
} from '../domain/coach-message-log.entity';
import { CoachMessageLogRepository } from '../domain/coach-message-log.repository';

export interface LogLiveTurnInput {
  userId: string;
  runId: string;
  author: CoachMessageAuthor;
  text: string;
  event?: CoachMessageEvent;
  kmAtTime?: number;
  paceAtTime?: string;
  bpmAtTime?: number;
  sessionGeneration?: number;
}

/**
 * Persiste um turno da sessão Gemini Live nativa em
 * `users/{uid}/runs/{runId}/coach_messages`. App chama via beacon
 * fire-and-forget a cada `turnComplete` (coach) ou `push_to_talk` (user).
 *
 * Diferente do CoachMessageUseCase (cues HTTP), a sessão Live conecta
 * direto no Google — esse log é a nossa única visibilidade do que rolou
 * pra replay e auditoria.
 */
export class LogLiveTurnUseCase {
  constructor(private readonly repo: CoachMessageLogRepository) {}

  async execute(input: LogLiveTurnInput): Promise<void> {
    const text = input.text.trim();
    if (!text) return;
    const log: CoachMessageLog = {
      id: randomUUID(),
      runId: input.runId,
      userId: input.userId,
      author: input.author,
      event: input.event,
      text,
      kmAtTime: input.kmAtTime,
      paceAtTime: input.paceAtTime,
      bpmAtTime: input.bpmAtTime,
      promptVersion: 'live-coach.v1',
      promptSource: 'default',
      createdAt: new Date().toISOString(),
      liveTurn: true,
      sessionGeneration: input.sessionGeneration,
    };
    await this.repo.save(log);
  }
}
