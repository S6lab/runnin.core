import { Request, Response, NextFunction } from 'express';
import { FirestorePlanRepository } from '../infra/firestore-plan.repository';
import { FirestoreWeeklyReportRepository } from '../infra/firestore-weekly-report.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { GenerateWeeklyReportUseCase } from '../use-cases/generate-weekly-report.use-case';

const planRepo = new FirestorePlanRepository();
const reportRepo = new FirestoreWeeklyReportRepository();
const runRepo = new FirestoreRunRepository();
const generateWeeklyReport = new GenerateWeeklyReportUseCase(planRepo, runRepo, reportRepo);

export async function listWeeklyReportsHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const reports = await reportRepo.findByPlan(planId, req.uid);
    const ready = reports.filter((r) => r.status === 'ready');
    res.json({
      planId,
      weeks: ready.map((r) => ({
        weekNumber: r.weekNumber,
        weekStart: r.weekStart,
        weekEnd: r.weekEnd,
        status: r.status,
        metrics: r.metrics,
      })),
    });
  } catch (err) {
    next(err);
  }
}

export async function getWeeklyReportHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const weekNumber = Number(req.params['weekNumber']);
    if (!Number.isInteger(weekNumber) || weekNumber < 1) {
      res.status(400).json({ error: 'invalid_week_number' });
      return;
    }
    const report = await reportRepo.findByWeek(planId, weekNumber, req.uid);
    if (!report) {
      res.status(404).json({ error: 'not_found', code: 'WEEKLY_REPORT_NOT_FOUND' });
      return;
    }
    res.json(report);
  } catch (err) {
    next(err);
  }
}

export async function generateWeeklyReportHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const weekNumber = Number(req.params['weekNumber']);
    if (!Number.isInteger(weekNumber) || weekNumber < 1) {
      res.status(400).json({ error: 'invalid_week_number' });
      return;
    }
    const report = await generateWeeklyReport.execute(req.uid, planId, weekNumber);
    const statusCode = report.status === 'ready' ? 200 : 202;
    res.status(statusCode).json(report);
  } catch (err) {
    next(err);
  }
}
