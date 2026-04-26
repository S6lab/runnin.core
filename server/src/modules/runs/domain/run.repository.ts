import { Run, GpsPoint } from './run.entity';

export interface RunRepository {
  create(run: Run): Promise<void>;
  findById(id: string, userId: string): Promise<Run | null>;
  update(id: string, userId: string, data: Partial<Run>): Promise<void>;
  addGpsBatch(runId: string, userId: string, points: GpsPoint[]): Promise<void>;
  findByUser(userId: string, limit: number, cursor?: string): Promise<{ runs: Run[]; nextCursor?: string }>;
}
