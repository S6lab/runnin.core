import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/wearable_data.dart';

/// Remote datasource for syncing wearable data with the backend
class WearableRemoteDatasource {
  final Dio _dio;
  final String _baseUrl;

  WearableRemoteDatasource({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  /// Sync wearable data to backend
  Future<Map<String, dynamic>> syncData({
    List<HeartRateData>? heartRate,
    List<HRVData>? hrv,
    List<SleepData>? sleep,
    List<ActivityData>? activity,
    HeartRateZones? zones,
    RecoveryScore? recovery,
  }) async {
    try {
      final payload = <String, dynamic>{};

      if (heartRate != null && heartRate.isNotEmpty) {
        payload['heartRate'] = heartRate.map((d) => d.toJson()).toList();
      }
      if (hrv != null && hrv.isNotEmpty) {
        payload['hrv'] = hrv.map((d) => d.toJson()).toList();
      }
      if (sleep != null && sleep.isNotEmpty) {
        payload['sleep'] = sleep.map((d) => d.toJson()).toList();
      }
      if (activity != null && activity.isNotEmpty) {
        payload['activity'] = activity.map((d) => d.toJson()).toList();
      }
      if (zones != null) {
        payload['zones'] = zones.toJson();
      }
      if (recovery != null) {
        payload['recovery'] = recovery.toJson();
      }

      final response = await _dio.post(
        '$_baseUrl/api/wearable/sync',
        data: payload,
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error syncing wearable data: $e');
      rethrow;
    }
  }

  /// Update connection status on backend
  Future<void> updateConnectionStatus({
    required bool isConnected,
    required bool hasPermissions,
    String? deviceName,
    String? deviceType,
  }) async {
    try {
      // Connection status is updated automatically during sync
      // This is a placeholder for explicit status updates
      await _dio.post(
        '$_baseUrl/api/wearable/sync',
        data: {},
      );
    } catch (e) {
      debugPrint('Error updating connection status: $e');
      rethrow;
    }
  }

  /// Get connection status from backend
  Future<WearableConnection> getConnectionStatus() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/wearable/connection',
      );

      return WearableConnection.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error getting connection status: $e');
      rethrow;
    }
  }

  /// Get heart rate zones from backend
  Future<HeartRateZones?> getHeartRateZones() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/wearable/zones',
      );

      return HeartRateZones.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return null;
      }
      debugPrint('Error getting heart rate zones: $e');
      rethrow;
    }
  }

  /// Get recovery scores from backend
  Future<List<RecoveryScore>> getRecoveryScores({int limit = 7}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/api/wearable/recovery',
        queryParameters: {'limit': limit},
      );

      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => RecoveryScore.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting recovery scores: $e');
      return [];
    }
  }
}
