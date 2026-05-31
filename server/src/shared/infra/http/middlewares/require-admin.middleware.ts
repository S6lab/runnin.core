import { Request, Response, NextFunction } from 'express';
import { getAuth } from '@shared/infra/firebase/firebase.client';
import { ForbiddenError, UnauthorizedError } from '@shared/errors/app-error';

/**
 * Enforces that the requester has admin custom claim (`claims.admin === true` or `claims.role === 'admin'`).
 * Runs after authMiddleware (which sets req.uid).
 */
export async function requireAdmin(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    if (!req.uid) throw new UnauthorizedError('Missing uid');

    const user = await getAuth().getUser(req.uid);
    const claims = (user.customClaims ?? {}) as Record<string, unknown>;
    const isAdmin =
      claims.admin === true ||
      claims.role === 'admin' ||
      (Array.isArray(claims.roles) && claims.roles.includes('admin'));

    if (!isAdmin) throw new ForbiddenError('Admin role required');
    next();
  } catch (err) {
    next(err instanceof UnauthorizedError || err instanceof ForbiddenError ? err : new ForbiddenError());
  }
}
