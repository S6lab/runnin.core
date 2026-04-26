import { Request, Response, NextFunction } from 'express';
import { FirestoreUserRepository } from '../infra/firestore-user.repository';
import { GetProfileUseCase } from '../domain/use-cases/get-profile.use-case';
import { UpsertProfileUseCase, UpsertProfileSchema } from '../domain/use-cases/upsert-profile.use-case';
import { CompleteOnboardingUseCase, CompleteOnboardingSchema } from '../domain/use-cases/complete-onboarding.use-case';
import { ProvisionUserSchema, ProvisionUserUseCase } from '../domain/use-cases/provision-user.use-case';

const repo = new FirestoreUserRepository();
const getProfile = new GetProfileUseCase(repo);
const upsertProfile = new UpsertProfileUseCase(repo);
const completeOnboarding = new CompleteOnboardingUseCase(repo);
const provisionUser = new ProvisionUserUseCase(repo);

export async function getMe(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = await getProfile.execute(req.uid);
    res.json(user);
  } catch (err) {
    next(err);
  }
}

export async function patchMe(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = UpsertProfileSchema.parse(req.body);
    const user = await upsertProfile.execute(req.uid, input);
    res.json(user);
  } catch (err) {
    next(err);
  }
}

export async function postOnboarding(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = CompleteOnboardingSchema.parse(req.body);
    const result = await completeOnboarding.execute(req.uid, input);
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postProvision(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = ProvisionUserSchema.parse(req.body ?? {});
    const user = await provisionUser.execute(req.uid, input);
    res.status(201).json(user);
  } catch (err) {
    next(err);
  }
}
