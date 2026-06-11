import { Router, Request, Response } from 'express';
import { internalTokenMiddleware } from '@shared/infra/http/middlewares/internal-token.middleware';
import { invalidatePromptsCache } from '@shared/infra/llm/prompts/config-store';
import { logger } from '@shared/logger/logger';

/**
 * Rotas s2s pro admin do runnin-api (thin proxy): o editor de prompts vive
 * lá; quando salva/invalida, faz fan-out pra cá pro config-store deste
 * processo não servir prompt velho por até 60s de cache.
 */
export const internalRouter = Router();
internalRouter.use(internalTokenMiddleware);

internalRouter.post('/prompts/invalidate-cache', (_req: Request, res: Response) => {
  invalidatePromptsCache();
  logger.info('s6ai.prompts.cache_invalidated');
  res.json({ ok: true });
});
