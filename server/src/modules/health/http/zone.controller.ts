import { Request, Response, NextFunction } from 'express';
import { GetZonesUseCase } from '../use-cases/get-zones.use-case';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';

const userRepo = new FirestoreUserRepository();
const runRepo = new FirestoreRunRepository();
const getZones = new GetZonesUseCase(userRepo, runRepo);

export async function getZonesHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const zones = await getZones.execute(req.uid);
    res.json(zones);
  } catch (err) {
    next(err);
  }
}
