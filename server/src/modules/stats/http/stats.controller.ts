import { Request, Response, NextFunction } from 'express';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { GetStatsAggregateUseCase } from '../domain/use-cases/get-stats-aggregate.use-case';
import { StatsPeriod } from '../domain/stats-aggregate.entity';

const runRepo = new FirestoreRunRepository();
const getStats = new GetStatsAggregateUseCase(runRepo);

const VALID_PERIODS: StatsPeriod[] = ['week', 'month', 'threeMonths'];

export async function getStatsAggregate(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const period = req.query['period'] as string;
    if (!VALID_PERIODS.includes(period as StatsPeriod)) {
      res.status(400).json({ error: `Invalid period. Use one of: ${VALID_PERIODS.join(', ')}` });
      return;
    }
    const result = await getStats.execute(req.uid, period as StatsPeriod);
    res.json(result);
  } catch (err) {
    next(err);
  }
}
