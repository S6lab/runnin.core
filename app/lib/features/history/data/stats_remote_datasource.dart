import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/history/domain/entities/stats_aggregate.dart';
import 'package:runnin/features/history/domain/entities/stats_breakdown.dart';

/// Remote datasource for history stats.
/// Calls /v1/stats/aggregate (deltas) and /v1/stats/breakdown (DADOS:
/// stats consolidados + séries planejado-vs-realizado de volume e pace).
class StatsRemoteDatasource {
  final Dio _dio;
  StatsRemoteDatasource() : _dio = apiClient;

  /// period: 'week' | 'month' | 'threeMonths'
  /// tzOffsetMin: server calcula as janelas CIVIS (semana/mês) na TZ do
  /// device — mesma razão do breakdown; sem isso os deltas comparavam
  /// janelas rolling UTC e divergiam dos valores civis exibidos.
  Future<StatsAggregate> getAggregate(String period) async {
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    final res = await _dio.get(
      '/stats/aggregate',
      queryParameters: {'period': period, 'tzOffsetMin': tz},
    );
    return StatsAggregate.fromJson(res.data as Map<String, dynamic>);
  }

  /// Stats consolidados (11 métricas) + buckets de volume/pace por período.
  /// `tzOffsetMin` é o offset local do device vs UTC (BRT = -180). Sem ele
  /// o server (UTC) calculava "esta semana" começando segunda 00h UTC e
  /// runs feitas tarde da noite local sumiam.
  Future<StatsBreakdown> getBreakdown(String period) async {
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    final res = await _dio.get(
      '/stats/breakdown',
      queryParameters: {'period': period, 'tzOffsetMin': tz},
    );
    // TF 75 Fase 11: dump do payload pra investigar bug recorrente do
    // gráfico errado em Histórico/Dados/Semana. Eduardo já reportou 2x;
    // sem ver o payload real é impossível diagnosticar.
    try {
      final raw = jsonEncode(res.data);
      final preview = raw.length > 1800 ? '${raw.substring(0, 1800)}…' : raw;
      Logger.info('stats.breakdown.dump', context: {
        'period': period,
        'tzOffsetMin': '$tz',
        'rawPreview': preview,
        'rawLen': '${raw.length}',
      });
    } catch (_) {/* best-effort */}
    return StatsBreakdown.fromJson(res.data as Map<String, dynamic>);
  }
}
