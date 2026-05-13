import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/gamification/data/models/badge.dart';
import 'package:runnin/features/gamification/data/models/user_gamification.dart';

class GamificationRemoteDatasource {
  final Dio _dio;
  GamificationRemoteDatasource() : _dio = apiClient;

  Future<UserGamification> getProfile() async {
    final res = await _dio.get('/gamification/profile');
    return UserGamification.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Badge>> getBadges() async {
    final res = await _dio.get('/gamification/badges');
    final data = res.data as Map<String, dynamic>;
    final badgesList = data['badges'] as List<dynamic>;
    return badgesList
        .map((json) => Badge.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
