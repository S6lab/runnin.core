import { CoachMessageLog } from '../domain/coach-message-log.entity';
import { CoachMessageLogRepository } from '../domain/coach-message-log.repository';
import { FirestoreCoachMessageLogRepository } from '../infra/firestore-coach-message-log.repository';

/**
 * Replay do histórico de falas do coach de uma run. Extraído do
 * coach-message.use-case quando a geração de cues migrou pro s6-ai —
 * a persistência (beacon /coach/live-turn) e a leitura continuam aqui,
 * porque o histórico vive no schema do app (users/{uid}/runs/{runId}).
 */
export class ListCoachMessagesUseCase {
  constructor(
    private readonly messageLog: CoachMessageLogRepository =
      new FirestoreCoachMessageLogRepository(),
  ) {}

  async execute(userId: string, runId: string): Promise<CoachMessageLog[]> {
    return this.messageLog.listByRun(userId, runId);
  }
}
