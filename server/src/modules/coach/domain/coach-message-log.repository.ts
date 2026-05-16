import { CoachMessageLog } from './coach-message-log.entity';

export interface CoachMessageLogRepository {
  save(log: CoachMessageLog): Promise<void>;
  listByRun(userId: string, runId: string): Promise<CoachMessageLog[]>;
}
