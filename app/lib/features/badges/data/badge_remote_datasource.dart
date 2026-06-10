import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/badges/domain/entities/badge.dart';

class BadgeRemoteDatasource {
  final Dio _dio;
  BadgeRemoteDatasource() : _dio = apiClient;

  Future<List<Badge>> getMine() async {
    final res = await _dio.get('/badges/me');
    final list = (res.data['badges'] as List?) ?? const [];
    return list
        .map((e) => Badge.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Badge>> getRecentUnseen() async {
    final res = await _dio.get('/badges/recent-unseen');
    final list = (res.data['badges'] as List?) ?? const [];
    return list
        .map((e) => Badge.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> markSeen(String badgeId) async {
    await _dio.post('/badges/$badgeId/mark-seen');
  }

  Future<void> trackShare(String badgeId) async {
    await _dio.post('/badges/$badgeId/share');
  }
}
