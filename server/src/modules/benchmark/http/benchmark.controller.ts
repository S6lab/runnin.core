import { Request, Response, NextFunction } from 'express';
import { BenchmarkRepository } from '@modules/benchmark/domain/benchmark.repository';
import { GetBenchmarkUseCase } from '@modules/benchmark/domain/use-cases/get-benchmark.use-case';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';

const repo = new BenchmarkRepository();
const getBenchmark = new GetBenchmarkUseCase(repo);
const runRepo = new FirestoreRunRepository();
const userRepo = new FirestoreUserRepository();

export async function getBenchmarkHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const level = req.query.level as string;
    const runType = req.query.runType as string;
    const distance = req.query.distance as string;

    if (!level || !runType || !distance) {
      res.status(400).json({
        error: 'Missing required query params: level, runType, distance',
      });
      return;
    }

    const result = await getBenchmark.execute(req.uid, { level, runType, distance });
    res.json(result);
  } catch (err) {
    next(err);
  }
}

function distanceBand(distanceM: number): string {
  const km = distanceM / 1000;
  if (km < 7.5) return '5k';
  if (km < 12.5) return '10k';
  if (km < 18) return '15k';
  return '21k';
}

export async function getBenchmarkByRunIdHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const runId = req.params['runId'] as string;
    const run = await runRepo.findById(runId, req.uid);
    if (!run) {
      res.status(404).json({ error: 'Run not found' });
      return;
    }
    const user = await userRepo.findById(req.uid);
    if (!user) {
      res.status(404).json({ error: 'User profile not found' });
      return;
    }

    const raw = (await getBenchmark.execute(req.uid, {
      level: user.level,
      runType: run.type,
      distance: distanceBand(run.distanceM ?? 0),
    })) as {
      userPercentile: number;
      userValues: Record<string, unknown>;
      cohortValues: Record<string, unknown>;
      cohortSize: number;
    };

    const uv = raw.userValues ?? {};
    const cv = raw.cohortValues ?? {};
    const items: Array<{ label: string; userValue: string; cohortValue: string; betterIsLower: boolean }> = [];
    if (uv['pace'] && cv['pace']) {
      items.push({ label: 'PACE MÉDIO', userValue: String(uv['pace']), cohortValue: String(cv['pace']), betterIsLower: true });
    }
    if (uv['weeklyDistance'] && cv['weeklyDistance']) {
      items.push({ label: 'VOLUME SEMANAL', userValue: String(uv['weeklyDistance']), cohortValue: String(cv['weeklyDistance']), betterIsLower: false });
    }
    if (uv['consistency'] != null && cv['consistency'] != null) {
      items.push({ label: 'CONSISTÊNCIA', userValue: `${uv['consistency']}%`, cohortValue: `${cv['consistency']}%`, betterIsLower: false });
    }
    if (uv['avgBpm'] != null && cv['avgBpm'] != null) {
      items.push({ label: 'BPM MÉDIO', userValue: `${uv['avgBpm']} bpm`, cohortValue: `${cv['avgBpm']} bpm`, betterIsLower: true });
    }

    const percentileTop = Math.max(0, 100 - (raw.userPercentile ?? 0));
    res.json({ items, percentileTop, cohortSize: raw.cohortSize });
  } catch (err) {
    next(err);
  }
}

export const benchmarkRouter = {
  getBenchmark: [authMiddleware, getBenchmarkHandler],
  getBenchmarkByRunId: [authMiddleware, getBenchmarkByRunIdHandler],
};
