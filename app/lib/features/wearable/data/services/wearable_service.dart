import 'dart:io';
import 'package:health/health.dart';
import 'package:flutter/foundation.dart';
import '../models/wearable_data.dart';

/// Service for interacting with HealthKit (iOS) and Health Connect (Android)
class WearableService {
  final Health _health = Health();

  // Data types we want to access
  static final List<HealthDataType> _dataTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];

  /// Request permissions for health data access
  Future<bool> requestPermissions() async {
    try {
      // Configure permissions - read only for wearable data
      final permissions = _dataTypes
          .map((type) => HealthDataAccess.READ)
          .toList();

      // Request authorization
      final granted = await _health.requestAuthorization(
        _dataTypes,
        permissions: permissions,
      );

      return granted;
    } catch (e) {
      debugPrint('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final granted = await _health.hasPermissions(
        _dataTypes,
        permissions: _dataTypes
            .map((type) => HealthDataAccess.READ)
            .toList(),
      );
      return granted ?? false;
    } catch (e) {
      debugPrint('Error checking health permissions: $e');
      return false;
    }
  }

  /// Get connection status
  Future<WearableConnection> getConnectionStatus() async {
    try {
      final hasPerms = await hasPermissions();

      String? deviceType;
      if (Platform.isIOS) {
        deviceType = 'HealthKit';
      } else if (Platform.isAndroid) {
        deviceType = 'Health Connect';
      }

      return WearableConnection(
        isConnected: hasPerms,
        hasPermissions: hasPerms,
        deviceName: deviceType,
        deviceType: deviceType,
        lastSyncAt: hasPerms ? DateTime.now() : null,
      );
    } catch (e) {
      debugPrint('Error getting connection status: $e');
      return const WearableConnection(
        isConnected: false,
        hasPermissions: false,
      );
    }
  }

  /// Fetch heart rate data for a time range
  Future<List<HeartRateData>> getHeartRateData({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: end,
      );

      return healthData
          .where((data) => data.value is NumericHealthValue)
          .map((data) {
            final value = (data.value as NumericHealthValue).numericValue.toInt();
            return HeartRateData(
              bpm: value,
              timestamp: data.dateFrom,
              source: data.sourceName,
            );
          })
          .toList();
    } catch (e) {
      debugPrint('Error fetching heart rate data: $e');
      return [];
    }
  }

  /// Get resting heart rate (last 7 days average)
  Future<int?> getRestingHeartRate() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE],
        startTime: weekAgo,
        endTime: now,
      );

      if (healthData.isEmpty) return null;

      final values = healthData
          .where((data) => data.value is NumericHealthValue)
          .map((data) => (data.value as NumericHealthValue).numericValue.toInt())
          .toList();

      if (values.isEmpty) return null;

      // Return average
      return values.reduce((a, b) => a + b) ~/ values.length;
    } catch (e) {
      debugPrint('Error fetching resting heart rate: $e');
      return null;
    }
  }

  /// Fetch HRV data
  Future<List<HRVData>> getHRVData({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
        startTime: start,
        endTime: end,
      );

      return healthData
          .where((data) => data.value is NumericHealthValue)
          .map((data) {
            final value = (data.value as NumericHealthValue).numericValue;
            return HRVData(
              rmssd: value,
              timestamp: data.dateFrom,
              source: data.sourceName,
            );
          })
          .toList();
    } catch (e) {
      debugPrint('Error fetching HRV data: $e');
      return [];
    }
  }

  /// Fetch sleep data
  Future<List<SleepData>> getSleepData({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final sleepTypes = [
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_AWAKE,
      ];

      final healthData = await _health.getHealthDataFromTypes(
        types: sleepTypes,
        startTime: start,
        endTime: end,
      );

      // Group by sleep session (sessions starting on same day)
      final Map<String, List<HealthDataPoint>> sessions = {};

      for (final data in healthData) {
        final key = '${data.dateFrom.year}-${data.dateFrom.month}-${data.dateFrom.day}';
        sessions.putIfAbsent(key, () => []);
        sessions[key]!.add(data);
      }

      return sessions.entries.map((entry) {
        final points = entry.value;
        final startTime = points.map((p) => p.dateFrom).reduce((a, b) => a.isBefore(b) ? a : b);
        final endTime = points.map((p) => p.dateTo).reduce((a, b) => a.isAfter(b) ? a : b);

        int deepMinutes = 0;
        int remMinutes = 0;
        int lightMinutes = 0;
        int awakeMinutes = 0;

        for (final point in points) {
          final duration = point.dateTo.difference(point.dateFrom).inMinutes;
          switch (point.type) {
            case HealthDataType.SLEEP_DEEP:
              deepMinutes += duration;
              break;
            case HealthDataType.SLEEP_REM:
              remMinutes += duration;
              break;
            case HealthDataType.SLEEP_LIGHT:
              lightMinutes += duration;
              break;
            case HealthDataType.SLEEP_AWAKE:
              awakeMinutes += duration;
              break;
            default:
              break;
          }
        }

        return SleepData(
          startTime: startTime,
          endTime: endTime,
          durationHours: endTime.difference(startTime).inMinutes / 60.0,
          deepSleepMinutes: deepMinutes > 0 ? deepMinutes : null,
          remSleepMinutes: remMinutes > 0 ? remMinutes : null,
          lightSleepMinutes: lightMinutes > 0 ? lightMinutes : null,
          awakeMinutes: awakeMinutes > 0 ? awakeMinutes : null,
          source: points.first.sourceName,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching sleep data: $e');
      return [];
    }
  }

  /// Fetch daily activity data
  Future<List<ActivityData>> getActivityData({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.STEPS,
          HealthDataType.DISTANCE_DELTA,
          HealthDataType.ACTIVE_ENERGY_BURNED,
        ],
        startTime: start,
        endTime: end,
      );

      // Group by day
      final Map<String, Map<HealthDataType, List<HealthDataPoint>>> dailyData = {};

      for (final data in healthData) {
        final key = '${data.dateFrom.year}-${data.dateFrom.month}-${data.dateFrom.day}';
        dailyData.putIfAbsent(key, () => {});
        dailyData[key]!.putIfAbsent(data.type, () => []);
        dailyData[key]![data.type]!.add(data);
      }

      return dailyData.entries.map((entry) {
        final dateKey = entry.key.split('-');
        final date = DateTime(
          int.parse(dateKey[0]),
          int.parse(dateKey[1]),
          int.parse(dateKey[2]),
        );

        int steps = 0;
        double distance = 0;
        int calories = 0;

        final data = entry.value;

        if (data.containsKey(HealthDataType.STEPS)) {
          steps = data[HealthDataType.STEPS]!
              .where((p) => p.value is NumericHealthValue)
              .map((p) => (p.value as NumericHealthValue).numericValue.toInt())
              .fold(0, (a, b) => a + b);
        }

        if (data.containsKey(HealthDataType.DISTANCE_DELTA)) {
          distance = data[HealthDataType.DISTANCE_DELTA]!
              .where((p) => p.value is NumericHealthValue)
              .map((p) => (p.value as NumericHealthValue).numericValue)
              .fold(0.0, (a, b) => a + b) / 1000; // meters to km
        }

        if (data.containsKey(HealthDataType.ACTIVE_ENERGY_BURNED)) {
          calories = data[HealthDataType.ACTIVE_ENERGY_BURNED]!
              .where((p) => p.value is NumericHealthValue)
              .map((p) => (p.value as NumericHealthValue).numericValue.toInt())
              .fold(0, (a, b) => a + b);
        }

        return ActivityData(
          date: date,
          steps: steps,
          distanceKm: distance > 0 ? distance : null,
          activeMinutes: null, // Not directly available
          caloriesBurned: calories > 0 ? calories : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching activity data: $e');
      return [];
    }
  }

  /// Calculate heart rate zones based on resting and max HR
  Future<HeartRateZones?> calculateHeartRateZones({
    int? maxHeartRate,
  }) async {
    try {
      final restingHR = await getRestingHeartRate();
      if (restingHR == null) return null;

      // Estimate max HR if not provided (220 - age formula)
      // In production, this should come from user profile or fitness test
      final maxHR = maxHeartRate ?? 190; // Default estimate

      return HeartRateZones.calculate(
        restingHeartRate: restingHR,
        maxHeartRate: maxHR,
      );
    } catch (e) {
      debugPrint('Error calculating heart rate zones: $e');
      return null;
    }
  }

  /// Calculate recovery score based on recent HRV and sleep data
  Future<RecoveryScore?> calculateRecoveryScore() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final weekAgo = now.subtract(const Duration(days: 7));

      // Get recent HRV
      final hrvData = await getHRVData(start: yesterday, end: now);
      if (hrvData.isEmpty) return null;

      final latestHRV = hrvData.last.rmssd;

      // Get HRV baseline (7-day average)
      final baselineHRV = await getHRVData(start: weekAgo, end: now);
      if (baselineHRV.isEmpty) return null;

      final avgHRV = baselineHRV
          .map((d) => d.rmssd)
          .reduce((a, b) => a + b) / baselineHRV.length;

      // Get recent sleep
      final sleepData = await getSleepData(start: yesterday, end: now);

      // Calculate score (0-100)
      // Higher HRV vs baseline = better recovery
      // More sleep = better recovery
      double score = 50.0;

      // HRV component (0-50 points)
      final hrvRatio = latestHRV / avgHRV;
      score += (hrvRatio - 1.0) * 50; // +/-50 points based on deviation

      // Sleep component (0-50 points)
      if (sleepData.isNotEmpty) {
        final sleepHours = sleepData.last.durationHours;
        if (sleepHours >= 7.5) {
          score += 25;
        } else if (sleepHours >= 6.0) {
          score += 15;
        }

        // Quality bonus from deep/REM sleep
        final deepMinutes = sleepData.last.deepSleepMinutes ?? 0;
        final remMinutes = sleepData.last.remSleepMinutes ?? 0;
        if (deepMinutes + remMinutes > 180) {
          score += 25;
        } else if (deepMinutes + remMinutes > 120) {
          score += 15;
        }
      }

      // Clamp to 0-100
      score = score.clamp(0, 100);

      String recommendation;
      if (score >= 80) {
        recommendation = 'Excelente recuperação. Pronto para treino intenso.';
      } else if (score >= 60) {
        recommendation = 'Boa recuperação. Treino moderado recomendado.';
      } else if (score >= 40) {
        recommendation = 'Recuperação parcial. Considere treino leve.';
      } else {
        recommendation = 'Recuperação baixa. Priorize descanso.';
      }

      return RecoveryScore(
        score: score,
        date: now,
        recommendation: recommendation,
      );
    } catch (e) {
      debugPrint('Error calculating recovery score: $e');
      return null;
    }
  }

  /// Stream real-time heart rate during workout
  /// Note: This requires workout session to be active
  Stream<HeartRateData> streamHeartRate() async* {
    try {
      // Poll every 5 seconds during active workout
      while (true) {
        await Future.delayed(const Duration(seconds: 5));

        final now = DateTime.now();
        final recent = now.subtract(const Duration(seconds: 10));

        final data = await getHeartRateData(start: recent, end: now);
        if (data.isNotEmpty) {
          yield data.last;
        }
      }
    } catch (e) {
      debugPrint('Error streaming heart rate: $e');
    }
  }
}
