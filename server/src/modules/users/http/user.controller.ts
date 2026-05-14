import { Request, Response, NextFunction } from 'express';
import { FirestoreUserRepository } from '../infra/firestore-user.repository';
import { GetProfileUseCase } from '../domain/use-cases/get-profile.use-case';
import { UpsertProfileUseCase, UpsertProfileSchema } from '../domain/use-cases/upsert-profile.use-case';
import { CompleteOnboardingUseCase, CompleteOnboardingSchema } from '../domain/use-cases/complete-onboarding.use-case';
import { ProvisionUserSchema, ProvisionUserUseCase } from '../domain/use-cases/provision-user.use-case';
import { ActivateTrialUseCase } from '../domain/use-cases/activate-trial.use-case';
import { GetRunPreferencesUseCase } from '../domain/use-cases/get-run-preferences.use-case';
import { UpdateRunPreferencesUseCase, UpdateRunPreferencesSchema } from '../domain/use-cases/update-run-preferences.use-case';
import { GetMusicPreferencesUseCase } from '../domain/use-cases/get-music-preferences.use-case';
import { UpdateMusicPreferencesUseCase, UpdateMusicPreferencesSchema } from '../domain/use-cases/update-music-preferences.use-case';

const repo = new FirestoreUserRepository();
const getProfile = new GetProfileUseCase(repo);
const upsertProfile = new UpsertProfileUseCase(repo);
const completeOnboarding = new CompleteOnboardingUseCase(repo);
const provisionUser = new ProvisionUserUseCase(repo);
const activateTrial = new ActivateTrialUseCase(repo);
const getRunPreferences = new GetRunPreferencesUseCase(repo);
const updateRunPreferences = new UpdateRunPreferencesUseCase(repo);
const getMusicPreferences = new GetMusicPreferencesUseCase(repo);
const updateMusicPreferences = new UpdateMusicPreferencesUseCase(repo);

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

export async function postActivateTrial(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = await activateTrial.execute(req.uid);
    res.json(user);
  } catch (err) {
    next(err);
  }
}

export async function getRunPreferencesEndpoint(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const preferences = await getRunPreferences.execute(req.uid);
    res.json(preferences);
  } catch (err) {
    next(err);
  }
}

export async function patchRunPreferences(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = UpdateRunPreferencesSchema.parse(req.body);
    const user = await updateRunPreferences.execute(req.uid, input);
    res.json(user.runAlertPreferences);
  } catch (err) {
    next(err);
  }
}

export async function getMusicPreferencesEndpoint(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const preferences = await getMusicPreferences.execute(req.uid);
    res.json(preferences);
  } catch (err) {
    next(err);
  }
}

export async function patchMusicPreferences(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = UpdateMusicPreferencesSchema.parse(req.body);
    const user = await updateMusicPreferences.execute(req.uid, input);
    res.json(user.musicPreferences);
  } catch (err) {
    next(err);
  }
}
