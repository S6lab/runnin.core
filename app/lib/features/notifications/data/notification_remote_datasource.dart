import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/notifications/domain/entities/app_notification.dart';

class NotificationRemoteDatasource {
  final Dio _dio;
  NotificationRemoteDatasource() : _dio = apiClient;

  Future<List<AppNotification>> list() async {
    final res = await _dio.get('/notifications');
    final raw = (res.data as Map<String, dynamic>)['items'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<void> dismiss(String id) async {
    await _dio.post('/notifications/$id/dismiss');
  }

  Future<int> clear() async {
    final res = await _dio.post('/notifications/clear');
    final data = res.data as Map<String, dynamic>;
    return (data['dismissed'] as int?) ?? 0;
  }

  Future<void> markRead(String id) async {
    await _dio.post('/notifications/$id/read');
  }
}
