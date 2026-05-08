import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { AppError, CooldownError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

export function errorMiddleware(err: unknown, req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof ZodError) {
    res.status(422).json({
      error: { code: 'VALIDATION_ERROR', message: 'Invalid request data', details: err.issues },
    });
    return;
  }

  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error(err.message, { requestId: req.id, stack: err.stack });
    }
    const body: Record<string, unknown> = { code: err.code, message: err.message };
    if (err instanceof CooldownError) body['availableAt'] = err.availableAt;
    res.status(err.statusCode).json({ error: body });
    return;
  }

  const asError = err instanceof Error ? err : undefined;
  logger.error('Unhandled error', {
    requestId: req.id,
    errorMessage: asError?.message ?? String(err),
    errorName: asError?.name,
    stack: asError?.stack,
    err,
  });
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } });
}
