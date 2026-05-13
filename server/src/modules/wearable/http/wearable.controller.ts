import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { firestore } from '@shared/infra/firebase/admin';
import { syncWearableData } from '../domain/use-cases/sync-wearable-data.use-case';
import { WearableSyncPayload } from '../domain/wearable-data.entity';

// Validation schemas
const HeartRateDataSchema = z.object({
  bpm: z.number(),
  timestamp: z.string(),
  source: z.string().optional(),
});

const HRVDataSchema = z.object({
  rmssd: z.number(),
  timestamp: z.string(),
  source: z.string().optional(),
});

const SleepDataSchema = z.object({
  startTime: z.string(),
  endTime: z.string(),
  durationHours: z.number(),
  deepSleepMinutes: z.number().optional(),
  remSleepMinutes: z.number().optional(),
  lightSleepMinutes: z.number().optional(),
  awakeMinutes: z.number().optional(),
  source: z.string().optional(),
});

const ActivityDataSchema = z.object({
  date: z.string(),
  steps: z.number(),
  distanceKm: z.number().optional(),
  activeMinutes: z.number().optional(),
  caloriesBurned: z.number().optional(),
  source: z.string().optional(),
});

const HeartRateZonesSchema = z.object({
  maxHeartRate: z.number(),
  restingHeartRate: z.number(),
  zone1Max: z.number(),
  zone2Max: z.number(),
  zone3Max: z.number(),
  zone4Max: z.number(),
  zone5Max: z.number(),
  calculatedAt: z.string(),
});

const RecoveryScoreSchema = z.object({
  score: z.number(),
  date: z.string(),
  recommendation: z.string().optional(),
});

const SyncPayloadSchema = z.object({
  heartRate: z.array(HeartRateDataSchema).optional(),
  hrv: z.array(HRVDataSchema).optional(),
  sleep: z.array(SleepDataSchema).optional(),
  activity: z.array(ActivityDataSchema).optional(),
  zones: HeartRateZonesSchema.optional(),
  recovery: RecoveryScoreSchema.optional(),
});

/**
 * POST /api/wearable/sync
 * Sync wearable data from client
 */
export async function postSync(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const payload = SyncPayloadSchema.parse(req.body) as WearableSyncPayload;
    const result = await syncWearableData({ userId: req.uid, payload }, firestore);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/wearable/connection
 * Get current wearable connection status
 */
export async function getConnection(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const connectionDoc = await firestore
      .collection('wearable_connections')
      .doc(req.uid)
      .get();

    if (!connectionDoc.exists) {
      res.json({
        isConnected: false,
        hasPermissions: false,
      });
      return;
    }

    res.json(connectionDoc.data());
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/wearable/heart-rate
 * Get recent heart rate data
 */
export async function getHeartRate(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = Math.min(Number(req.query.limit ?? 100), 500);
    const hours = Math.min(Number(req.query.hours ?? 24), 168); // Max 7 days

    const since = new Date();
    since.setHours(since.getHours() - hours);

    const snapshot = await firestore
      .collection('wearable_heart_rate')
      .where('userId', '==', req.uid)
      .where('timestamp', '>=', since.toISOString())
      .orderBy('timestamp', 'desc')
      .limit(limit)
      .get();

    const data = snapshot.docs.map(doc => doc.data());
    res.json(data);
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/wearable/zones
 * Get user's heart rate zones
 */
export async function getZones(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const zonesDoc = await firestore
      .collection('wearable_zones')
      .doc(req.uid)
      .get();

    if (!zonesDoc.exists) {
      res.status(404).json({ error: 'Heart rate zones not calculated yet' });
      return;
    }

    res.json(zonesDoc.data());
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/wearable/recovery
 * Get recent recovery scores
 */
export async function getRecovery(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = Math.min(Number(req.query.limit ?? 7), 30);

    const snapshot = await firestore
      .collection('wearable_recovery')
      .where('userId', '==', req.uid)
      .orderBy('date', 'desc')
      .limit(limit)
      .get();

    const data = snapshot.docs.map(doc => doc.data());
    res.json(data);
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/wearable/sleep
 * Get recent sleep data
 */
export async function getSleep(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = Math.min(Number(req.query.limit ?? 7), 30);

    const snapshot = await firestore
      .collection('wearable_sleep')
      .where('userId', '==', req.uid)
      .orderBy('startTime', 'desc')
      .limit(limit)
      .get();

    const data = snapshot.docs.map(doc => doc.data());
    res.json(data);
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/wearable/activity
 * Get recent activity data
 */
export async function getActivity(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = Math.min(Number(req.query.limit ?? 7), 30);

    const snapshot = await firestore
      .collection('wearable_activity')
      .where('userId', '==', req.uid)
      .orderBy('date', 'desc')
      .limit(limit)
      .get();

    const data = snapshot.docs.map(doc => doc.data());
    res.json(data);
  } catch (err) {
    next(err);
  }
}
