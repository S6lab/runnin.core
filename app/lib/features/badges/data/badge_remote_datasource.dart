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

  /// TF 79: teaser de próximo badge mais perto de desbloquear. Server retorna
  /// null quando user já tem tudo ou está muito longe do mais próximo
  /// (< 5% de progresso).
  Future<NextBadgeProgress?> getNext() async {
    final res = await _dio.get('/badges/next');
    final n = res.data['next'];
    if (n == null) return null;
    return NextBadgeProgress.fromJson(n as Map<String, dynamic>);
  }
}

class NextBadgeProgress {
  final String badgeId;
  final String category;
  final String title;
  final String subtitle;
  final double current;
  final double target;
  final double progress;
  final String remaining;
  final String unit;

  const NextBadgeProgress({
    required this.badgeId,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.target,
    required this.progress,
    required this.remaining,
    required this.unit,
  });

  factory NextBadgeProgress.fromJson(Map<String, dynamic> j) => NextBadgeProgress(
        badgeId: j['badgeId'] as String,
        category: j['category'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        current: (j['current'] as num).toDouble(),
        target: (j['target'] as num).toDouble(),
        progress: (j['progress'] as num).toDouble(),
        remaining: j['remaining'] as String,
        unit: j['unit'] as String,
      );
}
