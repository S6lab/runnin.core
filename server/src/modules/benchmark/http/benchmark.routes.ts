import { Router } from 'express';
import { benchmarkRouter as router } from './benchmark.controller';

export const benchmarkRoutes = Router();

benchmarkRoutes.get('/', ...router.getBenchmark);
benchmarkRoutes.get('/:runId', ...router.getBenchmarkByRunId);
