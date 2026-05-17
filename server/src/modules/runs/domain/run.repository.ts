import { Run, GpsPoint } from './run.entity';

export interface RunRepository {
  create(run: Run): Promise<void>;
  findById(id: string, userId: string): Promise<Run | null>;
  update(id: string, userId: string, data: Partial<Run>): Promise<void>;
  addGpsBatch(runId: string, userId: string, points: GpsPoint[]): Promise<void>;
  listGpsPoints(runId: string, userId: string, limit?: number): Promise<GpsPoint[]>;
  findByUser(userId: string, limit: number, cursor?: string): Promise<{ runs: Run[]; nextCursor?: string }>;
  findByDateRange(userId: string, from: Date, to: Date): Promise<Run[]>;
}
