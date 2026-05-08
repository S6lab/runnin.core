import { Request, Response, NextFunction } from 'express';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { isPremium } from '@modules/users/domain/user.entity';
import { PremiumRequiredError } from '@shared/errors/app-error';

const userRepo = new FirestoreUserRepository();

export async function requirePremium(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    const profile = await userRepo.findById(req.uid);
    if (!isPremium(profile)) {
      throw new PremiumRequiredError('Recurso disponível apenas no plano Pro.');
    }
    next();
  } catch (err) {
    next(err);
  }
}
