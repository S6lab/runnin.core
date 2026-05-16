import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/subscriptions/domain/subscription_plan.dart';

class SubscriptionRemoteDatasource {
  final Dio _dio;
  SubscriptionRemoteDatasource() : _dio = apiClient;

  /// GET /v1/subscriptions/plans — catálogo público.
  Future<List<SubscriptionPlan>> listPlans() async {
    final res = await _dio.get('/subscriptions/plans');
    final list = (res.data as Map<String, dynamic>)['plans'] as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPlan.fromJson)
        .toList();
  }

  /// GET /v1/subscriptions/me — plano + features do user atual.
  Future<UserSubscription> getMine() async {
    final res = await _dio.get('/subscriptions/me');
    return UserSubscription.fromJson(res.data as Map<String, dynamic>);
  }
}
