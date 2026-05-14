import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

const _planCacheBoxName = 'runnin_plan_cache';

class PlanRemoteDatasource {
  final Dio _dio;
  PlanRemoteDatasource() : _dio = apiClient;

  Future<Box<String>> _planCacheBox() async {
    if (Hive.isBoxOpen(_planCacheBoxName)) {
      return Hive.box<String>(_planCacheBoxName);
    }
    return Hive.openBox<String>(_planCacheBoxName);
  }

  Future<Plan?> getCurrentPlan() async {
    try {
      final res = await _dio.get('/plans/current');
      final plan = Plan.fromJson(res.data as Map<String, dynamic>);
      await _cachePlan(plan);
      return plan;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 404) {
        return await getCachedPlan();
      }
      final cachedPlan = await getCachedPlan();
      if (cachedPlan != null) {
        return cachedPlan;
      }
      rethrow;
    } catch (e) {
      final cachedPlan = await getCachedPlan();
      if (cachedPlan != null) {
        return cachedPlan;
      }
      rethrow;
    }
  }

  Future<Plan?> getCachedPlan() async {
    try {
      final box = await _planCacheBox();
      final cachedJson = box.get('current_plan');
      if (cachedJson != null) {
        return Plan.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cachePlan(Plan plan) async {
    try {
      final box = await _planCacheBox();
      await box.put('current_plan', jsonEncode(plan.toJson()));
    } catch (_) {}
  }

  Future<String> generatePlan({
    required String goal,
    required String level,
    int? frequency,
    int? weeksCount,
  }) async {
    final res = await _dio.post(
      '/plans/generate',
      data: {
        'goal': goal,
        'level': level,
        if (weeksCount != null) 'weeksCount': weeksCount,
        if (frequency != null) 'frequency': frequency,
      },
    );
    return (res.data as Map<String, dynamic>)['planId'] as String;
  }

  Future<Plan> getPlanById(String planId) async {
    final res = await _dio.get('/plans/$planId');
    final plan = Plan.fromJson(res.data as Map<String, dynamic>);
    await _cachePlan(plan);
    return plan;
  }

  Future<void> updateSessionStatus({
    required String planId,
    required String sessionId,
    required String status,
  }) async {
    await _dio.patch(
      '/plans/$planId/sessions/$sessionId',
      data: {'status': status},
    );
  }

  Future<void> rescheduleSession({
    required String planId,
    required String sessionId,
    required String newDate,
  }) async {
    await _dio.patch(
      '/plans/$planId/sessions/$sessionId',
      data: {'scheduledDate': newDate},
    );
  }
}
