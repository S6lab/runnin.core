import 'package:runnin/core/network/api_client.dart';

/// Métricas TECH consolidadas (GET /admin/metrics/tech): saúde dos
/// serviços, erros 24h/7d (`system/errors/daily`, alimentado pelo wrapper
/// do logger) e custo LLM hoje/7d.
class AdminMetricsDatasource {
  Future<TechMetrics> getTech() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/metrics/tech');
    return TechMetrics.fromJson(res.data ?? const {});
  }
}

class ServiceHealth {
  final String name;
  final bool ok;
  final int? latencyMs;
  final String? error;

  const ServiceHealth({required this.name, required this.ok, this.latencyMs, this.error});

  factory ServiceHealth.fromJson(Map<String, dynamic> j) => ServiceHealth(
        name: j['name'] as String? ?? '?',
        ok: j['ok'] == true,
        latencyMs: (j['latencyMs'] as num?)?.toInt(),
        error: j['error'] as String?,
      );
}

class ErrorsDay {
  final String date;
  final int total;
  final Map<String, int> byService;
  final Map<String, int> byMessageKey;

  const ErrorsDay({
    required this.date,
    required this.total,
    required this.byService,
    required this.byMessageKey,
  });

  factory ErrorsDay.fromJson(Map<String, dynamic> j) => ErrorsDay(
        date: j['date'] as String? ?? '',
        total: (j['total'] as num?)?.toInt() ?? 0,
        byService: _intMap(j['byService']),
        byMessageKey: _intMap(j['byMessageKey']),
      );

  static Map<String, int> _intMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
  }
}

class TechMetrics {
  final List<ServiceHealth> services;
  final ErrorsDay? errorsToday;
  final List<ErrorsDay> errorsLast7d;
  final int errorsTotal7d;
  final double llmCostTodayUsd;
  final double llmCost7dUsd;

  const TechMetrics({
    required this.services,
    required this.errorsToday,
    required this.errorsLast7d,
    required this.errorsTotal7d,
    required this.llmCostTodayUsd,
    required this.llmCost7dUsd,
  });

  factory TechMetrics.fromJson(Map<String, dynamic> j) {
    final errors = j['errors'] as Map<String, dynamic>? ?? const {};
    final llm = j['llmCost'] as Map<String, dynamic>? ?? const {};
    return TechMetrics(
      services: ((j['services'] as List?) ?? const [])
          .map((s) => ServiceHealth.fromJson(s as Map<String, dynamic>))
          .toList(),
      errorsToday: errors['today'] != null
          ? ErrorsDay.fromJson(errors['today'] as Map<String, dynamic>)
          : null,
      errorsLast7d: ((errors['last7d'] as List?) ?? const [])
          .map((d) => ErrorsDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      errorsTotal7d: (errors['total7d'] as num?)?.toInt() ?? 0,
      llmCostTodayUsd: (llm['todayUsd'] as num?)?.toDouble() ?? 0,
      llmCost7dUsd: (llm['last7dUsd'] as num?)?.toDouble() ?? 0,
    );
  }
}
