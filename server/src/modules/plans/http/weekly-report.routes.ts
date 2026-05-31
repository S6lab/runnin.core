import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import {
  listMyWeeklyReportsHandler,
  getMyWeeklyReportByWeekStartHandler,
} from './weekly-report.controller';

/**
 * Top-level shortcut pra UI: app não precisa saber o planId pra listar
 * weekly reports. Esse router resolve o plano atual do user e devolve
 * direto a lista achatada.
 */
export const weeklyReportRouter = Router();
weeklyReportRouter.use(authMiddleware);

weeklyReportRouter.get('/', listMyWeeklyReportsHandler);
weeklyReportRouter.get('/:weekStart', getMyWeeklyReportByWeekStartHandler);
