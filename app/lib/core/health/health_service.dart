import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HealthService {
  static const _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static const _settingsBox = 'runnin_settings';
  static const _connectedKey = 'health_connected';

  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

  Box<dynamic>? _box() {
    if (!Hive.isBoxOpen(_settingsBox)) return null;
    return Hive.box<dynamic>(_settingsBox);
  }

  bool get isConnected => _box()?.get(_connectedKey) == true;

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    try {
      final health = Health();
      await health.configure();
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      final granted = await health.requestAuthorization(
        _types,
        permissions: permissions,
      );
      if (granted) {
        await _box()?.put(_connectedKey, true);
      }
      return granted;
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'health_request_permissions',
      );
      return false;
    }
  }

  Future<HealthSnapshot?> fetchSnapshot() async {
    if (!isSupported || !isConnected) return null;
    try {
      final health = Health();
      await health.configure();
      final now = DateTime.now();
      final since = now.subtract(const Duration(hours: 24));

      final points = await health.getHealthDataFromTypes(
        startTime: since,
        endTime: now,
        types: _types,
      );

      double? avgBpm;
      double? sleepHours;

      final bpmPoints =
          points.where((p) => p.type == HealthDataType.HEART_RATE).toList();
      if (bpmPoints.isNotEmpty) {
        final sum = bpmPoints.fold<double>(
          0,
          (s, p) =>
              s + (p.value as NumericHealthValue).numericValue.toDouble(),
        );
        avgBpm = sum / bpmPoints.length;
      }

      final sleepPoints =
          points.where((p) => p.type == HealthDataType.SLEEP_ASLEEP).toList();
      if (sleepPoints.isNotEmpty) {
        sleepHours = sleepPoints.fold<double>(
          0,
          (s, p) => s + p.dateTo.difference(p.dateFrom).inMinutes / 60.0,
        );
      }

      return HealthSnapshot(avgBpm: avgBpm, sleepHours: sleepHours);
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'health_fetch_snapshot',
      );
      return null;
    }
  }

  Future<void> disconnect() async {
    await _box()?.delete(_connectedKey);
  }
}

class HealthSnapshot {
  final double? avgBpm;
  final double? sleepHours;

  const HealthSnapshot({this.avgBpm, this.sleepHours});
}
