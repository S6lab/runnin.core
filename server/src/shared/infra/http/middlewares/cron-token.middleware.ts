import { Request, Response, NextFunction } from 'express';
import { UnauthorizedError } from '@shared/errors/app-error';

export function cronTokenMiddleware(req: Request, _res: Response, next: NextFunction): void {
  const cronToken = process.env.X_CRON_TOKEN;
  if (!cronToken) {
    next(new UnauthorizedError('X-CRON-TOKEN env var not configured'));
    return;
  }

  const headerToken = req.headers['x-cron-token'];
  if (!headerToken || headerToken !== cronToken) {
    next(new UnauthorizedError('Invalid or missing X-CRON-TOKEN header'));
    return;
  }

  next();
}
