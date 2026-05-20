import { Request, Response, NextFunction } from 'express';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { GetStatsAggregateUseCase } from '../domain/use-cases/get-stats-aggregate.use-case';
import { GetUserTotalsUseCase } from '../domain/use-cases/get-user-totals.use-case';
import { GetStatsBreakdownUseCase } from '../domain/use-cases/get-stats-breakdown.use-case';
import { StatsPeriod } from '../domain/stats-aggregate.entity';

const runRepo = new FirestoreRunRepository();
const planRepo = new FirestorePlanRepository();
const getStats = new GetStatsAggregateUseCase(runRepo);
const getUserTotals = new GetUserTotalsUseCase(runRepo);
const getBreakdown = new GetStatsBreakdownUseCase(runRepo, planRepo);

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

export async function getStatsBreakdown(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const period = req.query['period'] as string;
    if (!VALID_PERIODS.includes(period as StatsPeriod)) {
      res.status(400).json({ error: `Invalid period. Use one of: ${VALID_PERIODS.join(', ')}` });
      return;
    }
    const result = await getBreakdown.execute(req.uid, period as StatsPeriod);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

export async function getUserTotalsHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await getUserTotals.execute(req.uid);
    res.json(result);
  } catch (err) {
    next(err);
  }
}
