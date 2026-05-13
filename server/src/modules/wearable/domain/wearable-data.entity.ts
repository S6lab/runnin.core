/**
 * Wearable data entities for health and fitness tracking
 */

export interface HeartRateData {
  userId: string;
  bpm: number;
  timestamp: string;
  source?: string;
  createdAt: string;
}

export interface HRVData {
  userId: string;
  rmssd: number; // Root mean square of successive differences
  timestamp: string;
  source?: string;
  createdAt: string;
}

export interface SleepData {
  userId: string;
  startTime: string;
  endTime: string;
  durationHours: number;
  deepSleepMinutes?: number;
  remSleepMinutes?: number;
  lightSleepMinutes?: number;
  awakeMinutes?: number;
  source?: string;
  createdAt: string;
}

export interface ActivityData {
  userId: string;
  date: string;
  steps: number;
  distanceKm?: number;
  activeMinutes?: number;
  caloriesBurned?: number;
  source?: string;
  createdAt: string;
}

export interface HeartRateZones {
  userId: string;
  maxHeartRate: number;
  restingHeartRate: number;
  zone1Max: number; // 50-60% MHR
  zone2Max: number; // 60-70% MHR
  zone3Max: number; // 70-80% MHR
  zone4Max: number; // 80-90% MHR
  zone5Max: number; // 90-100% MHR
  calculatedAt: string;
  updatedAt: string;
}

export interface RecoveryScore {
  userId: string;
  score: number; // 0-100
  date: string;
  recommendation?: string;
  createdAt: string;
}

export interface WearableConnection {
  userId: string;
  isConnected: boolean;
  hasPermissions: boolean;
  deviceName?: string;
  deviceType?: string;
  lastSyncAt?: string;
  updatedAt: string;
}

/**
 * Batch sync payload from client
 */
export interface WearableSyncPayload {
  heartRate?: HeartRateData[];
  hrv?: HRVData[];
  sleep?: SleepData[];
  activity?: ActivityData[];
  zones?: Omit<HeartRateZones, 'userId' | 'updatedAt'>;
  recovery?: Omit<RecoveryScore, 'userId' | 'createdAt'>;
}
