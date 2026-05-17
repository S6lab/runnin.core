import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';

/// Sincroniza dados de Apple HealthKit (iOS) / Google Health Connect (Android)
/// com o backend runnin.
///
/// Uso:
///   final sync = HealthSyncService();
///   await sync.requestPermissions(); // 1x quando user habilitar
///   final result = await sync.syncSince(DateTime.now().subtract(Duration(days: 7)));
///
/// Não suportado em web — guard com [isSupported] antes.
class HealthSyncService {
  static const _hiveBoxName = 'runnin_settings';
  static const _lastSyncKey = 'biometrics_last_sync_at';

  final _health = Health();
  final _ds = BiometricRemoteDatasource();

  static const _types = <HealthDataType>[
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.STEPS,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WEIGHT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.RESPIRATORY_RATE,
  ];

  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    try {
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      final ok = await _health.requestAuthorization(_types, permissions: permissions);
      return ok;
    } catch (e) {
      debugPrint('HealthSyncService.requestPermissions failed: $e');
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    if (!isSupported) return false;
    try {
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      final ok = await _health.hasPermissions(_types, permissions: permissions);
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Sincroniza samples desde `since` (ou desde o último sync, ou últimos 7d
  /// se primeira vez). Retorna número de samples enviados.
  Future<int> syncSince([DateTime? since]) async {
    if (!isSupported) return 0;
    final from = since ?? await _readLastSync() ?? DateTime.now().subtract(const Duration(days: 7));
    final to = DateTime.now();

    List<HealthDataPoint> raw;
    try {
      raw = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime: to,
        types: _types,
      );
    } catch (e) {
      debugPrint('HealthSyncService.fetch failed: $e');
      return 0;
    }

    final samples = raw
        .map(_mapToInput)
        .where((s) => s != null)
        .cast<BiometricSampleInput>()
        .toList();

    if (samples.isEmpty) {
      await _saveLastSync(to);
      return 0;
    }

    // Backend aceita até 500/req; chunk em batches.
    int totalSaved = 0;
    for (var i = 0; i < samples.length; i += 500) {
      final batch = samples.sublist(i, (i + 500).clamp(0, samples.length));
      try {
        final result = await _ds.ingest(batch);
        totalSaved += result.saved;
      } catch (e) {
        debugPrint('HealthSyncService.ingest batch failed: $e');
      }
    }

    await _saveLastSync(to);
    return totalSaved;
  }

  BiometricSampleInput? _mapToInput(HealthDataPoint p) {
    final type = _typeMap[p.type];
    if (type == null) return null;
    final rawValue = p.value;
    final value = rawValue is NumericHealthValue
        ? rawValue.numericValue
        : double.tryParse(rawValue.toString());
    if (value == null) return null;

    return BiometricSampleInput(
      type: type,
      value: value,
      unit: _unitMap[p.type] ?? p.unit.name,
      source: _sourceLabel,
      recordedAt: p.dateFrom.toUtc().toIso8601String(),
      context: {
        'sourceName': p.sourceName,
        if (p.dateFrom != p.dateTo)
          'dateToUtc': p.dateTo.toUtc().toIso8601String(),
      },
    );
  }

  String get _sourceLabel {
    if (!isSupported) return 'manual';
    if (Platform.isIOS) return 'apple_health';
    if (Platform.isAndroid) return 'health_connect';
    return 'manual';
  }

  static const _typeMap = <HealthDataType, String>{
    HealthDataType.HEART_RATE: 'bpm',
    HealthDataType.RESTING_HEART_RATE: 'resting_bpm',
    HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'hrv',
    HealthDataType.SLEEP_ASLEEP: 'sleep_hours',
    HealthDataType.SLEEP_DEEP: 'sleep_deep',
    HealthDataType.STEPS: 'steps',
    HealthDataType.BLOOD_OXYGEN: 'spo2',
    HealthDataType.WEIGHT: 'weight',
    HealthDataType.ACTIVE_ENERGY_BURNED: 'calories_burned',
    HealthDataType.RESPIRATORY_RATE: 'respiratory_rate',
  };

  static const _unitMap = <HealthDataType, String>{
    HealthDataType.HEART_RATE: 'bpm',
    HealthDataType.RESTING_HEART_RATE: 'bpm',
    HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'ms',
    HealthDataType.SLEEP_ASLEEP: 'hours',
    HealthDataType.SLEEP_DEEP: 'hours',
    HealthDataType.STEPS: 'count',
    HealthDataType.BLOOD_OXYGEN: '%',
    HealthDataType.WEIGHT: 'kg',
    HealthDataType.ACTIVE_ENERGY_BURNED: 'kcal',
    HealthDataType.RESPIRATORY_RATE: 'rpm',
  };

  Future<DateTime?> _readLastSync() async {
    if (!Hive.isBoxOpen(_hiveBoxName)) return null;
    final raw = Hive.box<dynamic>(_hiveBoxName).get(_lastSyncKey);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<void> _saveLastSync(DateTime ts) async {
    final box = Hive.isBoxOpen(_hiveBoxName)
        ? Hive.box<dynamic>(_hiveBoxName)
        : await Hive.openBox<dynamic>(_hiveBoxName);
    await box.put(_lastSyncKey, ts.toIso8601String());
  }
}

final healthSyncService = HealthSyncService();
