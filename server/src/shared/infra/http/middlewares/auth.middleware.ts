import { Request, Response, NextFunction } from 'express';
import { getAuth } from '@shared/infra/firebase/firebase.client';
import { UnauthorizedError } from '@shared/errors/app-error';

declare global {
  namespace Express {
    interface Request {
      uid: string;
    }
  }
}

export async function authMiddleware(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) throw new UnauthorizedError('Missing token');

    const token = authHeader.slice(7);
    const decoded = await getAuth().verifyIdToken(token);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    next(err instanceof UnauthorizedError ? err : new UnauthorizedError());
  }
}
