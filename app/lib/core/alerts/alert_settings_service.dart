import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:runnin/core/alerts/alert_settings.dart';
import 'package:runnin/core/network/api_client.dart';

class AlertSettingsService {
  static const String _boxName = 'alert_settings';
  
  late final Box<AlertSettings> _box;
  final Dio _dio;
  
  AlertSettingsService._internal() : _dio = apiClient {
    init();
  }
  
  static final AlertSettingsService _instance = AlertSettingsService._internal();
  
  factory AlertSettingsService() => _instance;
  
  Future<void> init() async {
    _box = await Hive.openBox<AlertSettings>(_boxName);
  }
  
  AlertSettings get settings {
    final value = _box.get('default');
    return value ?? AlertSettings.defaultSettings();
  }
  
  Future<void> updatePaceAlert(bool enabled) async {
    final current = settings;
    final newSettings = current.copyWith(paceAlertEnabled: enabled);
    await _box.put('default', newSettings);
    try {
      await _dio.patch('/alerts/pace', data: {'enabled': enabled});
    } catch (_) {
      // Persist locally even if backend fails
    }
  }
  
  Future<void> updateHeartRateAlert(bool enabled) async {
    final current = settings;
    final newSettings = current.copyWith(heartRateAlertEnabled: enabled);
    await _box.put('default', newSettings);
    try {
      await _dio.patch('/alerts/heart_rate', data: {'enabled': enabled});
    } catch (_) {
      // Persist locally even if backend fails
    }
  }
  
  Future<void> updateDistanceMarkAlert(bool enabled) async {
    final current = settings;
    final newSettings = current.copyWith(distanceMarkAlertEnabled: enabled);
    await _box.put('default', newSettings);
    try {
      await _dio.patch('/alerts/distance', data: {'enabled': enabled});
    } catch (_) {
      // Persist locally even if backend fails
    }
  }
  
  Future<void> dispose() async {
    await _box.close();
  }
}
