import { Router, Request, Response, NextFunction } from 'express';
import { internalTokenMiddleware } from '@shared/infra/http/middlewares/internal-token.middleware';
import { GenerateWeeksUseCase, GenerateWeeksRequestSchema } from './generate-weeks.use-case';
import { RevisePlanUseCase, RevisePlanRequestSchema } from './revise-plan.use-case';

// Rotas s2s (runnin-api → s6-ai). Sem token de usuário: geração também é
// disparada por cron (weekly proposals), então a auth é X-Internal-Token e
// o userId vem no payload só pra atribuição de llm_usage.
const generateWeeks = new GenerateWeeksUseCase();
const revisePlan = new RevisePlanUseCase();

export const planRouter = Router();
planRouter.use(internalTokenMiddleware);

planRouter.post('/generate', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = GenerateWeeksRequestSchema.parse(req.body);
    const result = await generateWeeks.execute(input);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

planRouter.post('/revise', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = RevisePlanRequestSchema.parse(req.body);
    const result = await revisePlan.execute(input);
    res.json(result);
  } catch (err) {
    next(err);
  }
});
