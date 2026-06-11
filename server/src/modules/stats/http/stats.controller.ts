import { Request, Response, NextFunction } from 'express';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { GetStatsAggregateUseCase } from '../domain/use-cases/get-stats-aggregate.use-case';
import { GetUserTotalsUseCase } from '../domain/use-cases/get-user-totals.use-case';
import { GetStatsBreakdownUseCase } from '../domain/use-cases/get-stats-breakdown.use-case';
import { StatsPeriod } from '../domain/stats-aggregate.entity';

const runRepo = new FirestoreRunRepository();
const planRepo = new FirestorePlanRepository();
const userRepo = new FirestoreUserRepository();
const getStats = new GetStatsAggregateUseCase(runRepo, userRepo);
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
    // Mesma semântica do breakdown: janelas civis na TZ do user.
    const tzRaw = req.query['tzOffsetMin'];
    const tzOffsetMin = typeof tzRaw === 'string' && /^-?\d+$/.test(tzRaw)
      ? Math.max(-840, Math.min(840, Number(tzRaw)))
      : 0;
    const result = await getStats.execute(req.uid, period as StatsPeriod, tzOffsetMin);
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
    // Cliente envia `tzOffsetMin` (DateTime.now().timeZoneOffset.inMinutes)
    // pra server calcular buckets na TZ do user. BRT = -180. Cloud Run roda
    // em UTC; sem isso, runs feitas tarde da noite local caíam no dia UTC
    // seguinte e sumiam da "semana atual" reportada pela tela hist/dados.
    const tzRaw = req.query['tzOffsetMin'];
    const tzOffsetMin = typeof tzRaw === 'string' && /^-?\d+$/.test(tzRaw)
      ? Math.max(-840, Math.min(840, Number(tzRaw)))
      : 0;
    const result = await getBreakdown.execute(req.uid, period as StatsPeriod, tzOffsetMin);
    // TF 77: dump server-side pra investigar bug do volume planejado errado.
    // Logger.info do client tava silenciado em release → não tínhamos visibilidade.
    try {
      const { logger } = await import('@shared/logger/logger');
      logger.info('stats.breakdown.server_dump', {
        uid: req.uid,
        period,
        tzOffsetMin,
        volume: result.volume,
        pace: result.pace,
        statsRuns: result.stats?.runs,
        statsKm: result.stats?.totalDistanceKm,
      });
    } catch (_) {/* ignore */}
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
