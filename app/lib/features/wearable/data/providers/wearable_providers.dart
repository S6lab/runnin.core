import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wearable_data.dart';
import '../services/wearable_service.dart';

/// Provider for the wearable service singleton
final wearableServiceProvider = Provider<WearableService>((ref) {
  return WearableService();
});

/// Provider for current wearable connection status
final wearableConnectionProvider = FutureProvider<WearableConnection>((ref) async {
  final service = ref.watch(wearableServiceProvider);
  return service.getConnectionStatus();
});

/// Provider for resting heart rate
final restingHeartRateProvider = FutureProvider<int?>((ref) async {
  final service = ref.watch(wearableServiceProvider);
  return service.getRestingHeartRate();
});

/// Provider for heart rate zones
final heartRateZonesProvider = FutureProvider<HeartRateZones?>((ref) async {
  final service = ref.watch(wearableServiceProvider);
  return service.calculateHeartRateZones();
});

/// Provider for recent heart rate data (last 24 hours)
final recentHeartRateProvider = FutureProvider<List<HeartRateData>>((ref) async {
  final service = ref.watch(wearableServiceProvider);
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  return service.getHeartRateData(start: yesterday, end: now);
});

/// Provider for recent HRV data (last 7 days)
final recentHRVProvider = FutureProvider<List<HRVData>>((ref) async {
  final service = ref.watch(wearableServiceProvider);
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  return service.getHRVData(start: weekAgo, end: now);
});

/// Provider for recent sleep data (last 7 days)
final recentSleepProvider = FutureProvider<List<SleepData>>((ref) async {
  final service = ref.watch(wearableServiceProvider);
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  return service.getSleepData(start: weekAgo, end: now);
});

/// Provider for daily activity data (last 7 days)
final recentActivityProvider = FutureProvider<List<ActivityData>>((ref) async {
  final service = ref.watch(wearableServiceProvider);
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  return service.getActivityData(start: weekAgo, end: now);
});

/// Provider for recovery score
final recoveryScoreProvider = FutureProvider<RecoveryScore?>((ref) async {
  final service = ref.watch(wearableServiceProvider);
  return service.calculateRecoveryScore();
});

/// Stream provider for real-time heart rate during workout
final heartRateStreamProvider = StreamProvider<HeartRateData>((ref) {
  final service = ref.watch(wearableServiceProvider);
  return service.streamHeartRate();
});
