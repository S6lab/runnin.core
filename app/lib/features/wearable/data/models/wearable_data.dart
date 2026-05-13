import 'package:freezed_annotation/freezed_annotation.dart';

part 'wearable_data.freezed.dart';
part 'wearable_data.g.dart';

/// Represents wearable device connection status
@freezed
class WearableConnection with _$WearableConnection {
  const factory WearableConnection({
    required bool isConnected,
    required bool hasPermissions,
    String? deviceName,
    String? deviceType,
    DateTime? lastSyncAt,
  }) = _WearableConnection;

  factory WearableConnection.fromJson(Map<String, dynamic> json) =>
      _$WearableConnectionFromJson(json);
}

/// Heart rate data point
@freezed
class HeartRateData with _$HeartRateData {
  const factory HeartRateData({
    required int bpm,
    required DateTime timestamp,
    String? source,
  }) = _HeartRateData;

  factory HeartRateData.fromJson(Map<String, dynamic> json) =>
      _$HeartRateDataFromJson(json);
}

/// Heart rate variability data
@freezed
class HRVData with _$HRVData {
  const factory HRVData({
    required double rmssd, // Root mean square of successive differences
    required DateTime timestamp,
    String? source,
  }) = _HRVData;

  factory HRVData.fromJson(Map<String, dynamic> json) =>
      _$HRVDataFromJson(json);
}

/// Sleep data
@freezed
class SleepData with _$SleepData {
  const factory SleepData({
    required DateTime startTime,
    required DateTime endTime,
    required double durationHours,
    int? deepSleepMinutes,
    int? remSleepMinutes,
    int? lightSleepMinutes,
    int? awakeMinutes,
    String? source,
  }) = _SleepData;

  factory SleepData.fromJson(Map<String, dynamic> json) =>
      _$SleepDataFromJson(json);
}

/// Daily activity summary
@freezed
class ActivityData with _$ActivityData {
  const factory ActivityData({
    required DateTime date,
    required int steps,
    double? distanceKm,
    int? activeMinutes,
    int? caloriesBurned,
    String? source,
  }) = _ActivityData;

  factory ActivityData.fromJson(Map<String, dynamic> json) =>
      _$ActivityDataFromJson(json);
}

/// Heart rate zones for training
@freezed
class HeartRateZones with _$HeartRateZones {
  const factory HeartRateZones({
    required int maxHeartRate,
    required int restingHeartRate,
    required int zone1Max, // 50-60% MHR
    required int zone2Max, // 60-70% MHR
    required int zone3Max, // 70-80% MHR
    required int zone4Max, // 80-90% MHR
    required int zone5Max, // 90-100% MHR
    DateTime? calculatedAt,
  }) = _HeartRateZones;

  factory HeartRateZones.fromJson(Map<String, dynamic> json) =>
      _$HeartRateZonesFromJson(json);

  factory HeartRateZones.calculate({
    required int restingHeartRate,
    required int maxHeartRate,
  }) {
    // Using Karvonen formula (Heart Rate Reserve method)
    final hrr = maxHeartRate - restingHeartRate;

    return HeartRateZones(
      maxHeartRate: maxHeartRate,
      restingHeartRate: restingHeartRate,
      zone1Max: restingHeartRate + (hrr * 0.6).round(),
      zone2Max: restingHeartRate + (hrr * 0.7).round(),
      zone3Max: restingHeartRate + (hrr * 0.8).round(),
      zone4Max: restingHeartRate + (hrr * 0.9).round(),
      zone5Max: maxHeartRate,
      calculatedAt: DateTime.now(),
    );
  }
}

/// Recovery score based on HRV and sleep
@freezed
class RecoveryScore with _$RecoveryScore {
  const factory RecoveryScore({
    required double score, // 0-100
    required DateTime date,
    String? recommendation,
  }) = _RecoveryScore;

  factory RecoveryScore.fromJson(Map<String, dynamic> json) =>
      _$RecoveryScoreFromJson(json);
}
