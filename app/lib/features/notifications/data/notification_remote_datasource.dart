import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/notifications/domain/entities/app_notification.dart';

class NotificationPage {
  final List<AppNotification> items;
  final String? nextCursor;
  const NotificationPage(this.items, this.nextCursor);
}

class NotificationRemoteDatasource {
  final Dio _dio;
  NotificationRemoteDatasource() : _dio = apiClient;

  Future<NotificationPage> list({String? cursor, int? limit}) async {
    final res = await _dio.get(
      '/notifications',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    final data = res.data as Map<String, dynamic>;
    final raw = data['items'] as List<dynamic>? ?? const [];
    final items = raw
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
    final nextCursor = data['nextCursor'] as String?;
    return NotificationPage(items, nextCursor);
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
