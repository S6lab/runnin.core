# Wearable Integration Feature

This feature integrates with Apple HealthKit (iOS) and Google Health Connect (Android) to sync wearable device data for the Runnin app.

## Features Implemented

### Frontend (Flutter)

1. **Data Models** (`data/models/wearable_data.dart`)
   - `WearableConnection` - Connection status
   - `HeartRateData` - Heart rate data points
   - `HRVData` - Heart rate variability
   - `SleepData` - Sleep tracking
   - `ActivityData` - Daily activity (steps, distance, calories)
   - `HeartRateZones` - Personalized training zones
   - `RecoveryScore` - Recovery recommendations

2. **Wearable Service** (`data/services/wearable_service.dart`)
   - Permission requests for HealthKit/Health Connect
   - Fetch heart rate data (real-time and historical)
   - Fetch resting heart rate
   - Fetch HRV data
   - Fetch sleep data
   - Fetch activity data
   - Calculate personalized heart rate zones
   - Calculate recovery scores
   - Stream real-time heart rate during workouts

3. **Remote Datasource** (`data/services/wearable_remote_datasource.dart`)
   - Sync wearable data to backend
   - Get connection status
   - Get heart rate zones
   - Get recovery scores

4. **Riverpod Providers** (`data/providers/wearable_providers.dart`)
   - `wearableServiceProvider` - Service singleton
   - `wearableConnectionProvider` - Connection status
   - `restingHeartRateProvider` - Resting HR
   - `heartRateZonesProvider` - Training zones
   - `recentHeartRateProvider` - Recent HR data
   - `recentHRVProvider` - Recent HRV data
   - `recentSleepProvider` - Recent sleep data
   - `recentActivityProvider` - Recent activity data
   - `recoveryScoreProvider` - Recovery score
   - `heartRateStreamProvider` - Real-time HR stream

5. **UI Integration** (`features/profile/presentation/pages/health_page.dart`)
   - **Trends Tab**: Shows average HR, sleep, and recovery score
   - **Zones Tab**: Displays personalized heart rate zones
   - **Device Tab**: Wearable connection flow
   - **Exams Tab**: (Existing - for medical exams upload)

### Backend (Node.js/TypeScript)

1. **Data Entities** (`server/src/modules/wearable/domain/wearable-data.entity.ts`)
   - HeartRateData, HRVData, SleepData, ActivityData
   - HeartRateZones, RecoveryScore
   - WearableConnection
   - WearableSyncPayload

2. **Use Cases** (`server/src/modules/wearable/domain/use-cases/`)
   - `sync-wearable-data.use-case.ts` - Batch sync wearable data to Firestore

3. **HTTP Layer** (`server/src/modules/wearable/http/`)
   - `wearable.controller.ts` - API controllers
   - `wearable.routes.ts` - Route definitions

### Platform Configuration

1. **iOS** (`ios/Runner/Info.plist`)
   - Added `NSHealthShareUsageDescription`
   - Added `NSHealthUpdateUsageDescription`

2. **Android** (`android/app/src/main/AndroidManifest.xml`)
   - Added Health Connect permissions
   - Added Health Connect activity alias

## API Endpoints

### POST /api/wearable/sync
Sync wearable data from client to backend.

**Request Body:**
```json
{
  "heartRate": [{ "bpm": 142, "timestamp": "2026-05-13T10:00:00Z" }],
  "hrv": [{ "rmssd": 45.2, "timestamp": "2026-05-13T08:00:00Z" }],
  "sleep": [{ "startTime": "2026-05-12T23:00:00Z", "endTime": "2026-05-13T07:00:00Z", "durationHours": 8.0 }],
  "activity": [{ "date": "2026-05-13", "steps": 10234 }],
  "zones": { "restingHeartRate": 58, "maxHeartRate": 190, ... },
  "recovery": { "score": 84, "date": "2026-05-13", "recommendation": "..." }
}
```

**Response:**
```json
{
  "success": true,
  "synced": 6
}
```

### GET /api/wearable/connection
Get wearable connection status.

### GET /api/wearable/heart-rate?hours=24&limit=100
Get recent heart rate data.

### GET /api/wearable/zones
Get user's heart rate zones.

### GET /api/wearable/recovery?limit=7
Get recent recovery scores.

### GET /api/wearable/sleep?limit=7
Get recent sleep data.

### GET /api/wearable/activity?limit=7
Get recent activity data.

## Supported Wearable Devices

- **Apple Watch** (via HealthKit)
- **Garmin**
- **Samsung Galaxy Watch**
- **Fitbit**
- **Polar**
- **COROS**
- **Whoop**
- Any device compatible with Health Connect (Android) or HealthKit (iOS)

## Setup Instructions

### 1. Install Dependencies

```bash
cd app
flutter pub get
```

### 2. Generate Freezed Code

```bash
cd app
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Backend Setup

Add the wearable router to your main app file:

```typescript
import { wearableRouter } from './modules/wearable/http/wearable.routes';

// ...
app.use('/api/wearable', wearableRouter);
```

### 4. Firestore Collections

The following Firestore collections will be created automatically:
- `wearable_heart_rate` - Heart rate data points
- `wearable_hrv` - HRV data
- `wearable_sleep` - Sleep sessions
- `wearable_activity` - Daily activity
- `wearable_zones` - Heart rate zones (per user)
- `wearable_recovery` - Recovery scores
- `wearable_connections` - Connection status (per user)

### 5. iOS Setup

Enable HealthKit capability in Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability" and add "HealthKit"

### 6. Android Setup

Install Health Connect on your Android device:
- Android 14+: Built-in
- Android 13 and below: Install from Google Play Store

### 7. Testing

**iOS:**
- Test on a physical device with an Apple Watch paired
- Simulator has limited HealthKit functionality

**Android:**
- Test on a physical device or emulator with Health Connect installed
- Add sample data in Health Connect app for testing

## Usage Example

### Connect Wearable

```dart
final service = ref.read(wearableServiceProvider);
final granted = await service.requestPermissions();

if (granted) {
  // Permissions granted, start syncing
  ref.invalidate(wearableConnectionProvider);
}
```

### Display Real-time Heart Rate

```dart
final heartRateStream = ref.watch(heartRateStreamProvider);

heartRateStream.when(
  data: (hr) => Text('${hr.bpm} BPM'),
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

### Show Heart Rate Zones

```dart
final zones = ref.watch(heartRateZonesProvider);

zones.when(
  data: (z) {
    if (z == null) return Text('Connect wearable first');
    return Text('Zone 2: ${z.zone1Max}-${z.zone2Max} BPM');
  },
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

## Next Steps

1. **Background Sync**: Implement periodic background sync of wearable data
2. **Real-time HR Display**: Add real-time heart rate display on active run page
3. **Zone-based Training**: Use HR zones for workout recommendations
4. **Recovery Integration**: Factor recovery score into training plan adjustments
5. **Workout Detection**: Automatically detect and import workouts from wearables
6. **Charts & Trends**: Add data visualization for HR, sleep, and recovery trends
7. **Notifications**: Alert users when recovery is low or HR zones are off-target

## Troubleshooting

### iOS: "No data available"
- Check that HealthKit capability is enabled in Xcode
- Verify Info.plist has usage descriptions
- Ensure Health app has data from Apple Watch or iPhone

### Android: "Permission denied"
- Install Health Connect app
- Grant permissions in Health Connect settings
- Verify AndroidManifest.xml has correct permissions

### Backend: "Sync failed"
- Check Firebase admin credentials
- Verify Firestore security rules allow writes
- Check backend logs for detailed errors

## References

- [health package documentation](https://pub.dev/packages/health)
- [Apple HealthKit documentation](https://developer.apple.com/documentation/healthkit)
- [Google Health Connect documentation](https://developer.android.com/health-and-fitness/guides/health-connect)
