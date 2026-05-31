import { Request, Response, NextFunction } from 'express';
import { FirestorePlanRepository } from '../infra/firestore-plan.repository';
import { FirestoreWeeklyReportRepository } from '../infra/firestore-weekly-report.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { GenerateWeeklyReportUseCase } from '../use-cases/generate-weekly-report.use-case';
import { WeeklyReport } from '../domain/weekly-report.entity';

const planRepo = new FirestorePlanRepository();
const reportRepo = new FirestoreWeeklyReportRepository();
const runRepo = new FirestoreRunRepository();
const generateWeeklyReport = new GenerateWeeklyReportUseCase(planRepo, runRepo, reportRepo);

/**
 * Shape consumido pelo app (WeeklyReport.fromJson). Achatado a partir da
 * estrutura interna (metrics aninhada + coachHighlights[]) pra evitar
 * mapping no client.
 */
function toAppShape(r: WeeklyReport): Record<string, unknown> {
  const m = r.metrics;
  return {
    weekStart: r.weekStart,
    sessionsPlanned: m.plannedSessions,
    sessionsDone: m.completedRuns,
    totalKm: m.actualDistanceKm,
    plannedKm: m.plannedDistanceKm,
    highlights: r.coachHighlights && r.coachHighlights.length > 0
      ? r.coachHighlights.join('\n')
      : null,
    coachAnalysis: r.summary || null,
    averagePace: null,
    totalFreeSessions: 0,
    freeKm: 0,
    adaptationSuggestion: null,
  };
}

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

/**
 * Top-level endpoint pro app: resolve o plano atual do user e devolve a
 * lista de weekly reports já achatada no shape esperado pelo client.
 * Sem plano ou sem reports → [] (não 404).
 */
export async function listMyWeeklyReportsHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const plan = await planRepo.findCurrent(req.uid);
    if (!plan) {
      res.json([]);
      return;
    }
    const reports = await reportRepo.findByPlan(plan.id, req.uid);
    const ready = reports
      .filter((r) => r.status === 'ready')
      .sort((a, b) => a.weekNumber - b.weekNumber);
    res.json(ready.map(toAppShape));
  } catch (err) {
    next(err);
  }
}

/**
 * Top-level endpoint pro app: mesma resolução de plano atual, mas filtra
 * por weekStart (ISO date). 404 só quando plano existe mas a semana não.
 */
export async function getMyWeeklyReportByWeekStartHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const weekStart = (req.params['weekStart'] as string).trim();
    if (!weekStart) {
      res.status(400).json({ error: 'invalid_week_start' });
      return;
    }
    const plan = await planRepo.findCurrent(req.uid);
    if (!plan) {
      res.status(404).json({ error: 'not_found', code: 'NO_CURRENT_PLAN' });
      return;
    }
    const reports = await reportRepo.findByPlan(plan.id, req.uid);
    const match = reports.find(
      (r) => r.status === 'ready' && r.weekStart === weekStart,
    );
    if (!match) {
      res.status(404).json({ error: 'not_found', code: 'WEEKLY_REPORT_NOT_FOUND' });
      return;
    }
    res.json(toAppShape(match));
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
