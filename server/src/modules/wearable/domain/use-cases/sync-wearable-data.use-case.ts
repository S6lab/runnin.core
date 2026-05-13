import { WearableSyncPayload, WearableConnection } from '../wearable-data.entity';

export interface SyncWearableDataInput {
  userId: string;
  payload: WearableSyncPayload;
}

/**
 * Sync wearable data from client to Firestore
 * Handles batch sync of heart rate, HRV, sleep, activity, zones, and recovery data
 */
export async function syncWearableData(
  input: SyncWearableDataInput,
  firestore: FirebaseFirestore.Firestore
): Promise<{ success: boolean; synced: number }> {
  const { userId, payload } = input;
  const batch = firestore.batch();
  let syncCount = 0;

  try {
    // Sync heart rate data
    if (payload.heartRate && payload.heartRate.length > 0) {
      for (const hr of payload.heartRate) {
        const docRef = firestore
          .collection('wearable_heart_rate')
          .doc();
        batch.set(docRef, {
          ...hr,
          userId,
          createdAt: new Date().toISOString(),
        });
        syncCount++;
      }
    }

    // Sync HRV data
    if (payload.hrv && payload.hrv.length > 0) {
      for (const hrv of payload.hrv) {
        const docRef = firestore
          .collection('wearable_hrv')
          .doc();
        batch.set(docRef, {
          ...hrv,
          userId,
          createdAt: new Date().toISOString(),
        });
        syncCount++;
      }
    }

    // Sync sleep data
    if (payload.sleep && payload.sleep.length > 0) {
      for (const sleep of payload.sleep) {
        const docRef = firestore
          .collection('wearable_sleep')
          .doc();
        batch.set(docRef, {
          ...sleep,
          userId,
          createdAt: new Date().toISOString(),
        });
        syncCount++;
      }
    }

    // Sync activity data
    if (payload.activity && payload.activity.length > 0) {
      for (const activity of payload.activity) {
        const docRef = firestore
          .collection('wearable_activity')
          .doc();
        batch.set(docRef, {
          ...activity,
          userId,
          createdAt: new Date().toISOString(),
        });
        syncCount++;
      }
    }

    // Sync/update heart rate zones
    if (payload.zones) {
      const zonesRef = firestore
        .collection('wearable_zones')
        .doc(userId);
      batch.set(
        zonesRef,
        {
          ...payload.zones,
          userId,
          updatedAt: new Date().toISOString(),
        },
        { merge: true }
      );
      syncCount++;
    }

    // Sync recovery score
    if (payload.recovery) {
      const recoveryRef = firestore
        .collection('wearable_recovery')
        .doc();
      batch.set(recoveryRef, {
        ...payload.recovery,
        userId,
        createdAt: new Date().toISOString(),
      });
      syncCount++;
    }

    // Update connection status
    const connectionRef = firestore
      .collection('wearable_connections')
      .doc(userId);
    batch.set(
      connectionRef,
      {
        userId,
        isConnected: true,
        hasPermissions: true,
        lastSyncAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      { merge: true }
    );

    // Update user profile hasWearable flag
    const userRef = firestore.collection('users').doc(userId);
    batch.update(userRef, {
      hasWearable: true,
      updatedAt: new Date().toISOString(),
    });

    // Commit batch
    await batch.commit();

    return { success: true, synced: syncCount };
  } catch (error) {
    console.error('Error syncing wearable data:', error);
    throw error;
  }
}
