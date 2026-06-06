import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/analytics/analytics_service.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';

/// Sincroniza dados de Apple HealthKit (iOS) / Google Health Connect (Android)
/// com o backend runnin.
///
/// Uso:
///   final sync = HealthSyncService();
///   await sync.requestPermissions(); // 1x quando user habilitar
///   final result = await sync.syncSince(DateTime.now().subtract(Duration(days: 7)));
///
/// Não suportado em web — guard com [isSupported] antes.
class HealthSyncService {
  static const _hiveBoxName = 'runnin_settings';
  static const _lastSyncKey = 'biometrics_last_sync_at';

  final _health = Health();
  final _ds = BiometricRemoteDatasource();

  static const _types = <HealthDataType>[
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.STEPS,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WEIGHT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.RESPIRATORY_RATE,
  ];

  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Última hora que `syncSince()` completou com sucesso. Usado pela Home
  /// pra decidir se vale disparar sync de novo (idade > 6h). null antes
  /// do primeiro sync ou se o storage não estiver inicializado.
  Future<DateTime?> lastSyncedAt() => _readLastSync();

  /// True quando o último sync rolou há mais de [maxAge]. Útil pra
  /// triggers idempotentes ("se a última sync ficou velha, refaz").
  /// Default 30min: usuário ativo (que abre home algumas vezes por dia)
  /// mantém summary fresco pra carga muscular/sono/recovery refletirem
  /// dados do dia. Antes era 6h e a home aparecia desatualizada.
  Future<bool> isStale({Duration maxAge = const Duration(minutes: 30)}) async {
    final last = await lastSyncedAt();
    if (last == null) return true;
    return DateTime.now().difference(last) > maxAge;
  }

  /// Idempotente — chama `requestAuthorization` com a lista completa de
  /// [_types]. iOS HealthKit faz dedup automático: tipos já vistos pelo
  /// user (granted ou denied) viram no-op; tipos NUNCA pedidos antes
  /// (ex: SLEEP foi adicionado depois do user ter feito onboarding) abrem
  /// o sheet. Sem isso o user só via "Batimentos" na lista de
  /// Configurações → Saúde → Runnin e sleep/hrv/etc nunca chegavam.
  ///
  /// Chamada pela home no boot. Best-effort — erro silencioso (logs vão
  /// pro Crashlytics via wearable_permission_error já existente).
  Future<void> ensureAuthorizations() async {
    if (!isSupported) return;
    try {
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      await _health.requestAuthorization(_types, permissions: permissions);
      unawaited(_logPermissionsBreakdown(stage: 'after_ensure'));
    } catch (e, st) {
      analytics.recordError(
        e,
        st,
        reason: 'wearable_ensure_authorizations_failed',
        context: {'platform': _platformLabel},
      );
    }
  }

  String get _platformLabel {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) {
      analytics.logEvent('wearable_connect_skipped', params: {
        'reason': 'unsupported_platform',
        'platform': _platformLabel,
      });
      return false;
    }
    analytics.logEvent('wearable_permission_requested', params: {
      'platform': _platformLabel,
      'provider': _sourceLabel,
    });
    try {
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      final ok = await _health.requestAuthorization(_types, permissions: permissions);
      analytics.logEvent('wearable_permission_result', params: {
        'platform': _platformLabel,
        'provider': _sourceLabel,
        'granted': ok,
      });
      // Diagnóstico per-type: iOS deixa o user marcar "Allow All" e depois
      // revogar tipos individuais (ex: Sono) em Configurações > Saúde >
      // Runnin. `requestAuthorization` retorna `true` mesmo nesses casos —
      // por isso medimos a granted-list separadamente.
      unawaited(_logPermissionsBreakdown(stage: 'after_request'));
      return ok;
    } catch (e, st) {
      analytics.recordError(
        e,
        st,
        reason: 'wearable_request_permissions_failed',
        context: {'platform': _platformLabel, 'provider': _sourceLabel},
      );
      analytics.logEvent('wearable_permission_error', params: {
        'platform': _platformLabel,
        'provider': _sourceLabel,
        'error_type': e.runtimeType.toString(),
      });
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    if (!isSupported) return false;
    try {
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      final ok = await _health.hasPermissions(_types, permissions: permissions);
      return ok ?? false;
    } catch (e, st) {
      analytics.recordError(
        e,
        st,
        reason: 'wearable_has_permissions_failed',
        context: {'platform': _platformLabel},
      );
      return false;
    }
  }

  /// Emite `wearable_permissions_breakdown` com 1 boolean por tipo (mapeado
  /// pelo nome canônico server-side: bpm, resting_bpm, hrv, sleep_hours, ...).
  /// Necessário porque `requestAuthorization` retorna um único `granted` mesmo
  /// quando o user revogou tipos individuais — o Apple Health no iOS permite
  /// negar tipos específicos via Configurações sem invalidar a autorização
  /// geral. Ajuda a explicar "Sono = --" na home quando outros tipos estão
  /// chegando normalmente.
  Future<void> _logPermissionsBreakdown({required String stage}) async {
    if (!isSupported) return;
    final granted = <String, bool>{};
    for (final t in _types) {
      try {
        final ok = await _health.hasPermissions([t], permissions: [HealthDataAccess.READ]);
        granted[_typeMap[t] ?? t.name] = ok ?? false;
      } catch (_) {
        granted[_typeMap[t] ?? t.name] = false;
      }
    }
    analytics.logEvent('wearable_permissions_breakdown', params: {
      'platform': _platformLabel,
      'provider': _sourceLabel,
      'stage': stage,
      ...granted.map((k, v) => MapEntry('granted_$k', v ? 1 : 0)),
    });
  }

  /// Total de passos no intervalo [from, to]. Usado no detalhe da corrida pra
  /// exibir passos da sessão sem depender de um campo extra na Run entity
  /// (não temos, mas Apple Health/Health Connect agregam o número direto).
  /// Retorna null em erro ou plataforma não suportada — caller exibe "--".
  /// STEPS no HK vem como múltiplos samples (1 por minuto, ou por activity),
  /// então somamos os valores numéricos da janela.
  Future<int?> stepsBetween(DateTime from, DateTime to) async {
    if (!isSupported) return null;
    if (!to.isAfter(from)) return null;
    try {
      final samples = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime: to,
        types: const [HealthDataType.STEPS],
      );
      if (samples.isEmpty) return 0;
      double total = 0;
      for (final s in samples) {
        final raw = s.value;
        final v = raw is NumericHealthValue
            ? raw.numericValue
            : double.tryParse(raw.toString());
        if (v != null && v > 0) total += v;
      }
      return total.round();
    } catch (_) {
      return null;
    }
  }

  /// Lê o BPM mais recente dos últimos [withinSeconds] segundos. Usado pra
  /// alimentar a UI de BPM live durante a corrida (ActiveRunPage). Retorna
  /// null se não houver leitura recente ou se o plugin falhar — caller exibe
  /// '—' nesse caso. Erros são silenciosos (não bloqueia a UI da corrida).
  Future<int?> latestBpm({int withinSeconds = 180}) async {
    if (!isSupported) return null;
    try {
      final to = DateTime.now();
      final from = to.subtract(Duration(seconds: withinSeconds));
      final samples = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime: to,
        types: const [HealthDataType.HEART_RATE],
      );
      if (samples.isEmpty) return null;
      samples.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final raw = samples.first.value;
      final numeric = raw is NumericHealthValue
          ? raw.numericValue
          : double.tryParse(raw.toString());
      if (numeric == null) return null;
      return numeric.round();
    } catch (_) {
      // BPM live é best-effort — não loga toda iteração de polling pra
      // não inundar o Crashlytics; o gauge geral é capturado em
      // wearable_fetch_failed quando o sync periódico falha.
      return null;
    }
  }

  /// Sincroniza samples desde `since` (ou desde o último sync, ou últimos 7d
  /// se primeira vez). Retorna número de samples enviados.
  Future<int> syncSince([DateTime? since]) async {
    if (!isSupported) return 0;
    final from = since ?? await _readLastSync() ?? DateTime.now().subtract(const Duration(days: 7));
    final to = DateTime.now();

    List<HealthDataPoint> raw;
    try {
      raw = await _health.getHealthDataFromTypes(
        startTime: from,
        endTime: to,
        types: _types,
      );
    } catch (e, st) {
      analytics.recordError(
        e,
        st,
        reason: 'wearable_fetch_failed',
        context: {
          'platform': _platformLabel,
          'provider': _sourceLabel,
          'window_days': to.difference(from).inDays,
        },
      );
      analytics.logEvent('wearable_sync_failed', params: {
        'stage': 'fetch',
        'platform': _platformLabel,
        'provider': _sourceLabel,
      });
      return 0;
    }

    final samples = raw
        .map(_mapToInput)
        .where((s) => s != null)
        .cast<BiometricSampleInput>()
        .toList();

    // Breakdown por tipo do que veio do plugin — ajuda diagnosticar quando
    // sleep ou hrv aparece zerado em /home (esperamos sleep_hours>0 e
    // bpm>0; se sleep_hours=0 com bpm>0 = permissão de sono não concedida
    // ou Apple Health sem dados de sono).
    final byType = <String, int>{};
    for (final p in raw) {
      final key = _typeMap[p.type] ?? p.type.name;
      byType[key] = (byType[key] ?? 0) + 1;
    }
    // Por tipo dos samples MAPEADOS (pós-_mapToInput) — diff vs fetched mostra
    // quantos o plugin entregou com value=null ou tipo não mapeado. Não dá pra
    // medir "saved per type" diretamente porque `_ds.ingest` retorna só total,
    // mas em ingest bem-sucedido total_saved == samples.length, então
    // mapped_<type> serve como proxy útil.
    final mappedByType = <String, int>{};
    for (final s in samples) {
      mappedByType[s.type] = (mappedByType[s.type] ?? 0) + 1;
    }

    if (samples.isEmpty) {
      await _saveLastSync(to);
      analytics.logEvent('wearable_sync_completed', params: {
        'platform': _platformLabel,
        'provider': _sourceLabel,
        'samples_saved': 0,
        'samples_fetched': raw.length,
        ...byType.map((k, v) => MapEntry('fetched_$k', v)),
        ...mappedByType.map((k, v) => MapEntry('mapped_$k', v)),
      });
      return 0;
    }

    // Backend aceita até 500/req; chunk em batches.
    int totalSaved = 0;
    int failedBatches = 0;
    for (var i = 0; i < samples.length; i += 500) {
      final batch = samples.sublist(i, (i + 500).clamp(0, samples.length));
      try {
        final result = await _ds.ingest(batch);
        totalSaved += result.saved;
      } catch (e, st) {
        failedBatches++;
        analytics.recordError(
          e,
          st,
          reason: 'wearable_ingest_batch_failed',
          context: {
            'platform': _platformLabel,
            'provider': _sourceLabel,
            'batch_size': batch.length,
          },
        );
      }
    }

    await _saveLastSync(to);
    analytics.logEvent('wearable_sync_completed', params: {
      'platform': _platformLabel,
      'provider': _sourceLabel,
      'samples_saved': totalSaved,
      'samples_fetched': raw.length,
      'failed_batches': failedBatches,
      ...byType.map((k, v) => MapEntry('fetched_$k', v)),
      ...mappedByType.map((k, v) => MapEntry('mapped_$k', v)),
    });
    return totalSaved;
  }

  BiometricSampleInput? _mapToInput(HealthDataPoint p) {
    final type = _typeMap[p.type];
    if (type == null) return null;
    final rawValue = p.value;
    var value = rawValue is NumericHealthValue
        ? rawValue.numericValue
        : double.tryParse(rawValue.toString());
    if (value == null) return null;

    // Patch de unidade: plugin `health` 13.x entrega SLEEP_ASLEEP/SLEEP_DEEP
    // como duração em MINUTOS (somatório de samples de HKCategoryValueSleep
    // entre start e end), mas o server agrega `sleep_hours` assumindo horas.
    // Sem essa conversão, depois que a primeira noite de sono chega, o card
    // mostra "480h" em vez de "8h". Mantemos `_unitMap` como 'hours' e
    // dividimos aqui.
    if (p.type == HealthDataType.SLEEP_ASLEEP ||
        p.type == HealthDataType.SLEEP_DEEP) {
      value = value / 60.0;
    }

    return BiometricSampleInput(
      type: type,
      value: value,
      unit: _unitMap[p.type] ?? p.unit.name,
      source: _sourceLabel,
      recordedAt: p.dateFrom.toUtc().toIso8601String(),
      context: {
        'sourceName': p.sourceName,
        if (p.dateFrom != p.dateTo)
          'dateToUtc': p.dateTo.toUtc().toIso8601String(),
      },
    );
  }

  String get _sourceLabel {
    if (!isSupported) return 'manual';
    if (Platform.isIOS) return 'apple_health';
    if (Platform.isAndroid) return 'health_connect';
    return 'manual';
  }

  static const _typeMap = <HealthDataType, String>{
    HealthDataType.HEART_RATE: 'bpm',
    HealthDataType.RESTING_HEART_RATE: 'resting_bpm',
    HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'hrv',
    HealthDataType.SLEEP_ASLEEP: 'sleep_hours',
    HealthDataType.SLEEP_DEEP: 'sleep_deep',
    HealthDataType.STEPS: 'steps',
    HealthDataType.BLOOD_OXYGEN: 'spo2',
    HealthDataType.WEIGHT: 'weight',
    HealthDataType.ACTIVE_ENERGY_BURNED: 'calories_burned',
    HealthDataType.RESPIRATORY_RATE: 'respiratory_rate',
  };

  static const _unitMap = <HealthDataType, String>{
    HealthDataType.HEART_RATE: 'bpm',
    HealthDataType.RESTING_HEART_RATE: 'bpm',
    HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'ms',
    HealthDataType.SLEEP_ASLEEP: 'hours',
    HealthDataType.SLEEP_DEEP: 'hours',
    HealthDataType.STEPS: 'count',
    HealthDataType.BLOOD_OXYGEN: '%',
    HealthDataType.WEIGHT: 'kg',
    HealthDataType.ACTIVE_ENERGY_BURNED: 'kcal',
    HealthDataType.RESPIRATORY_RATE: 'rpm',
  };

  Future<DateTime?> _readLastSync() async {
    if (!Hive.isBoxOpen(_hiveBoxName)) return null;
    final raw = Hive.box<dynamic>(_hiveBoxName).get(_lastSyncKey);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<void> _saveLastSync(DateTime ts) async {
    final box = Hive.isBoxOpen(_hiveBoxName)
        ? Hive.box<dynamic>(_hiveBoxName)
        : await Hive.openBox<dynamic>(_hiveBoxName);
    await box.put(_lastSyncKey, ts.toIso8601String());
  }
}

final healthSyncService = HealthSyncService();
