import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

/// Espelha o payload do server `POST /v1/biometrics/samples`.
class BiometricSampleInput {
  final String type;
  final num value;
  final String unit;
  final String source;
  final String recordedAt;
  final Map<String, dynamic>? context;

  const BiometricSampleInput({
    required this.type,
    required this.value,
    required this.unit,
    required this.source,
    required this.recordedAt,
    this.context,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'unit': unit,
        'source': source,
        'recordedAt': recordedAt,
        if (context != null) 'context': context,
      };
}

class BiometricSummary {
  final int windowDays;
  final num? avgRestingBpm;
  final num? maxBpm;
  final num? avgSleepHours;
  /// Horas dormidas na noite mais recente (último dia com dados).
  final num? lastNightSleepHours;
  /// Score 0-100 de qualidade do sono médio. null se faltam stages no servidor
  /// (sem sleep_deep/sleep_rem). Cálculo em get-summary.use-case.ts.
  final num? avgSleepQualityScore;
  /// Horas médias por estágio. null se sem dados.
  final num? avgSleepDeepH;
  final num? avgSleepRemH;
  final num? avgSleepLightH;
  final num? totalSteps;
  final num? avgHrv;
  final num? latestWeight;
  final int sampleCount;

  const BiometricSummary({
    required this.windowDays,
    this.avgRestingBpm,
    this.maxBpm,
    this.avgSleepHours,
    this.lastNightSleepHours,
    this.avgSleepQualityScore,
    this.avgSleepDeepH,
    this.avgSleepRemH,
    this.avgSleepLightH,
    this.totalSteps,
    this.avgHrv,
    this.latestWeight,
    required this.sampleCount,
  });

  factory BiometricSummary.fromJson(Map<String, dynamic> j) => BiometricSummary(
        windowDays: (j['windowDays'] as num?)?.toInt() ?? 7,
        avgRestingBpm: j['avgRestingBpm'] as num?,
        maxBpm: j['maxBpm'] as num?,
        avgSleepHours: j['avgSleepHours'] as num?,
        lastNightSleepHours: j['lastNightSleepHours'] as num?,
        avgSleepQualityScore: j['avgSleepQualityScore'] as num?,
        avgSleepDeepH: j['avgSleepDeepH'] as num?,
        avgSleepRemH: j['avgSleepRemH'] as num?,
        avgSleepLightH: j['avgSleepLightH'] as num?,
        totalSteps: j['totalSteps'] as num?,
        avgHrv: j['avgHrv'] as num?,
        latestWeight: j['latestWeight'] as num?,
        sampleCount: (j['sampleCount'] as num?)?.toInt() ?? 0,
      );
}

class BiometricRemoteDatasource {
  final Dio _dio;
  BiometricRemoteDatasource() : _dio = apiClient;

  Future<({int received, int saved})> ingest(List<BiometricSampleInput> samples) async {
    if (samples.isEmpty) return (received: 0, saved: 0);
    final res = await _dio.post(
      '/biometrics/samples',
      data: {'samples': samples.map((s) => s.toJson()).toList()},
    );
    final data = res.data as Map<String, dynamic>;
    return (
      received: (data['received'] as num?)?.toInt() ?? 0,
      saved: (data['saved'] as num?)?.toInt() ?? 0,
    );
  }

  /// Heartbeat de abertura: chama server uncondicionalmente no bootstrap
  /// pra confirmar conectividade + auth, ANTES do syncSince rodar. Permite
  /// distinguir "user nem abriu o app" de "syncSince morreu silente".
  Future<void> syncPing({String? tfHint, String? platform}) async {
    try {
      await _dio.post(
        '/biometrics/sync-ping',
        data: {
          if (tfHint != null) 'tf': tfHint,
          if (platform != null) 'platform': platform,
        },
      );
    } catch (_) {/* best-effort */}
  }

  /// Posta metadata da última chamada syncSince pro server logar.
  /// Best-effort, falha silenciosa. Usado pra diagnosticar quando syncSince
  /// roda mas HK retorna 0 samples (sleep não chega ao server).
  Future<void> postSyncTelemetry({
    required DateTime from,
    required DateTime to,
    DateTime? lastSync,
    required int hkFetchedTotal,
    required int mappedTotal,
    Map<String, int>? byType,
    Map<String, int>? mappedByType,
    String? errorMsg,
  }) async {
    try {
      await _dio.post(
        '/biometrics/sync-telemetry',
        data: {
          'fromIso': from.toUtc().toIso8601String(),
          'toIso': to.toUtc().toIso8601String(),
          'lastSyncIso': lastSync?.toUtc().toIso8601String(),
          'hkFetchedTotal': hkFetchedTotal,
          'mappedTotal': mappedTotal,
          if (byType != null) 'byType': byType,
          if (mappedByType != null) 'mappedByType': mappedByType,
          if (errorMsg != null) 'errorMsg': errorMsg.substring(0, errorMsg.length.clamp(0, 500)),
        },
      );
    } catch (_) {/* best-effort */}
  }

  Future<BiometricSummary> getSummary({int windowDays = 7}) async {
    // Timeout defensivo: se o agregado server-side travar (já vimos
    // acontecer com janelas grandes), o try/catch nas callers (health
    // zones, run detail) marca _loading=false em vez de pendurar a tela
    // num card branco infinito.
    final res = await _dio.get(
      '/biometrics/summary',
      queryParameters: {'windowDays': windowDays},
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    return BiometricSummary.fromJson(res.data as Map<String, dynamic>);
  }
}
