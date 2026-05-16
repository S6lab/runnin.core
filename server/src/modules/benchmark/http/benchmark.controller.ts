import { Request, Response, NextFunction } from 'express';
import { BenchmarkRepository } from '@modules/benchmark/domain/benchmark.repository';
import { GetBenchmarkUseCase } from '@modules/benchmark/domain/use-cases/get-benchmark.use-case';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';

const repo = new BenchmarkRepository();
const getBenchmark = new GetBenchmarkUseCase(repo);

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

export const benchmarkRouter = { getBenchmark: [authMiddleware, getBenchmarkHandler] };
