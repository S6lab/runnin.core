import 'package:runnin/core/network/api_client.dart';

/// Métricas de token / custo USD agregadas em
/// `users/{uid}/llm_usage/{YYYY-MM-DD}` (per-user) +
/// `system/llm_usage/daily/{YYYY-MM-DD}` (crons). Tabela de pricing
/// vive em `server/src/shared/infra/llm/llm-pricing.ts`.
class AdminUsageDatasource {
  /// Range inclusive `[from, to]` no formato ISO `YYYY-MM-DD`. Quando
  /// `userId` informado, retorna só o breakdown desse user; caso contrário,
  /// agrega TODOS os users do range via collection group query.
  Future<UsageBreakdown> getTokens({
    required String from,
    required String to,
    String? userId,
  }) async {
    final res = await apiClient.get<Map<String, dynamic>>(
      '/admin/usage/tokens',
      queryParameters: {
        'from': from,
        'to': to,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
    );
    return UsageBreakdown.fromJson(res.data ?? const {});
  }

  Future<List<TopUserUsage>> topUsers({
    required String from,
    required String to,
    int limit = 20,
  }) async {
    final res = await apiClient.get<Map<String, dynamic>>(
      '/admin/usage/top-users',
      queryParameters: {'from': from, 'to': to, 'limit': limit},
    );
    final users = (res.data?['users'] as List?) ?? const [];
    return users
        .map((u) => TopUserUsage.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<UsageBreakdown> getSystemUsage({
    required String from,
    required String to,
  }) async {
    final res = await apiClient.get<Map<String, dynamic>>(
      '/admin/usage/system',
      queryParameters: {'from': from, 'to': to},
    );
    return UsageBreakdown.fromJson(res.data ?? const {});
  }

  Future<Map<String, ModelPricing>> getPricing() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/usage/pricing');
    final pricing = (res.data?['pricing'] as Map?) ?? const {};
    return pricing.map(
      (k, v) => MapEntry(k as String, ModelPricing.fromJson(v as Map<String, dynamic>)),
    );
  }
}

class UsageBreakdown {
  final UsageTotals totals;
  final List<DailyUsage> byDay;
  final Map<String, ModelUsage> byModel;
  final Map<String, UseCaseUsage> byUseCase;

  const UsageBreakdown({
    required this.totals,
    required this.byDay,
    required this.byModel,
    required this.byUseCase,
  });

  factory UsageBreakdown.fromJson(Map<String, dynamic> json) {
    final byDay = ((json['byDay'] as List?) ?? const [])
        .map((d) => DailyUsage.fromJson(d as Map<String, dynamic>))
        .toList();
    final byModel = ((json['byModel'] as Map?) ?? const {}).map(
      (k, v) =>
          MapEntry(k as String, ModelUsage.fromJson(v as Map<String, dynamic>)),
    );
    final byUseCase = ((json['byUseCase'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(
          k as String, UseCaseUsage.fromJson(v as Map<String, dynamic>)),
    );
    return UsageBreakdown(
      totals: UsageTotals.fromJson((json['totals'] as Map?)?.cast<String, dynamic>() ?? const {}),
      byDay: byDay,
      byModel: byModel,
      byUseCase: byUseCase,
    );
  }

  static const empty = UsageBreakdown(
    totals: UsageTotals(inputTokens: 0, outputTokens: 0, calls: 0, costUsd: 0),
    byDay: [],
    byModel: {},
    byUseCase: {},
  );
}

class UsageTotals {
  final int inputTokens;
  final int outputTokens;
  final int calls;
  final double costUsd;

  const UsageTotals({
    required this.inputTokens,
    required this.outputTokens,
    required this.calls,
    required this.costUsd,
  });

  factory UsageTotals.fromJson(Map<String, dynamic> json) => UsageTotals(
        inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
        calls: (json['calls'] as num?)?.toInt() ?? 0,
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
      );
}

class DailyUsage {
  final String date;
  final int totalInputTokens;
  final int totalOutputTokens;
  final int totalCalls;
  final double totalCostUsd;

  const DailyUsage({
    required this.date,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalCalls,
    required this.totalCostUsd,
  });

  factory DailyUsage.fromJson(Map<String, dynamic> json) => DailyUsage(
        date: (json['date'] as String?) ?? '',
        totalInputTokens: (json['totalInputTokens'] as num?)?.toInt() ?? 0,
        totalOutputTokens: (json['totalOutputTokens'] as num?)?.toInt() ?? 0,
        totalCalls: (json['totalCalls'] as num?)?.toInt() ?? 0,
        totalCostUsd: (json['totalCostUsd'] as num?)?.toDouble() ?? 0,
      );
}

class ModelUsage {
  final int input;
  final int output;
  final int calls;
  final double costUsd;

  const ModelUsage({
    required this.input,
    required this.output,
    required this.calls,
    required this.costUsd,
  });

  factory ModelUsage.fromJson(Map<String, dynamic> json) => ModelUsage(
        input: (json['input'] as num?)?.toInt() ?? 0,
        output: (json['output'] as num?)?.toInt() ?? 0,
        calls: (json['calls'] as num?)?.toInt() ?? 0,
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
      );
}

class UseCaseUsage {
  final int calls;
  final double costUsd;

  const UseCaseUsage({required this.calls, required this.costUsd});

  factory UseCaseUsage.fromJson(Map<String, dynamic> json) => UseCaseUsage(
        calls: (json['calls'] as num?)?.toInt() ?? 0,
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
      );
}

class TopUserUsage {
  final String userId;
  final double costUsd;
  final int calls;
  final int inputTokens;
  final int outputTokens;

  const TopUserUsage({
    required this.userId,
    required this.costUsd,
    required this.calls,
    required this.inputTokens,
    required this.outputTokens,
  });

  factory TopUserUsage.fromJson(Map<String, dynamic> json) => TopUserUsage(
        userId: (json['userId'] as String?) ?? '',
        costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
        calls: (json['calls'] as num?)?.toInt() ?? 0,
        inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
        outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
      );
}

class ModelPricing {
  final double inputPer1M;
  final double outputPer1M;

  const ModelPricing({required this.inputPer1M, required this.outputPer1M});

  factory ModelPricing.fromJson(Map<String, dynamic> json) => ModelPricing(
        inputPer1M: (json['inputPer1M'] as num?)?.toDouble() ?? 0,
        outputPer1M: (json['outputPer1M'] as num?)?.toDouble() ?? 0,
      );
}
