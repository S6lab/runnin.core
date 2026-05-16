import { Router } from 'express';
import { benchmarkRouter as router } from './benchmark.controller';

export const benchmarkRoutes = Router();

benchmarkRoutes.get('/', ...router.getBenchmark);
