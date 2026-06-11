import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '@shared/errors/app-error';

/**
 * Auth service-to-service: rotas admin/internas (preview de prompt,
 * invalidate-cache, leituras de usage) só aceitam chamadas do runnin-api
 * portando o token compartilhado do Secret Manager (S6_INTERNAL_TOKEN).
 * Usuários finais nunca batem nessas rotas direto.
 */
export function internalTokenMiddleware(req: Request, _res: Response, next: NextFunction): void {
  const expected = (process.env['S6_INTERNAL_TOKEN'] ?? '').trim();
  if (!expected) {
    next(new UnauthorizedError('S6_INTERNAL_TOKEN not configured'));
    return;
  }
  const got = (req.headers['x-internal-token'] as string | undefined)?.trim();
  if (got !== expected) {
    next(new UnauthorizedError('Invalid internal token'));
    return;
  }
  next();
}
