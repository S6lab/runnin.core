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
  /// Flag de backfill one-time. Set true depois que rodamos um sync com
  /// `from=30d` pra recuperar samples antigos que falharam por incompat
  /// de Zod no server. Ver comentário em syncSince.
  ///
  /// v1 → v2 (TF 42): bumped depois que descobrimos que o sleep value
  /// era o INT do enum HKCategoryValueSleepAnalysis (não duração).
  /// Backfill v1 sincronizou dados buggy. Server tinha 458 samples
  /// quebrados que deletamos via admin script. v2 força new backfill
  /// com a fórmula correta (dateTo - dateFrom).
  static const _backfillFlagKey = 'biometrics_backfill_v2';
  /// Último sync que incluiu o tier lento ([_slowTypes]). Medidas corporais
  /// e atividade agregada mudam devagar — consultar 1×/24h corta ~50% das
  /// queries HealthKit do sync típico.
  static const _lastSlowSyncKey = 'biometrics_last_slow_sync_at';
  /// Último `wearable_permissions_breakdown` emitido no boot (stage
  /// after_ensure). O breakdown roda 1 `hasPermissions` por tipo — barato
  /// demais pra justificar em TODA abertura, 1×/24h basta pra observability.
  static const _lastBreakdownLogKey = 'biometrics_breakdown_logged_at';

  final _health = Health();
  final _ds = BiometricRemoteDatasource();

  // Auditoria 2026-06: tipos clínicos sem consumo em summary/prompts/UI
  // (pressão arterial, ECG, eventos de FC, fibrilação atrial, temperatura
  // corporal) foram REMOVIDOS do request — deixavam o sheet do HealthKit
  // com 38 linhas e cara de app médico, e custavam 8 queries por sync.
  // Pra users existentes a Apple mantém os tipos já solicitados listados
  // em Ajustes→Saúde→Runnin; o corte vale pra novas instalações.

  /// Tier rápido — consultado em todos os syncs. Sinais que mudam ao longo do
  /// dia e alimentam home/recovery/checkpoint: FC, HRV, sono, passos,
  /// SpO2, calorias ativas, distância e freq. respiratória.
  static const _fastTypes = <HealthDataType>[
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    // SLEEP_ASLEEP é o agregado total (iPhone Health). Em iOS 16+, Apple
    // Watch reporta sleep stages granulares (DEEP/REM/LIGHT) e ASLEEP pode
    // vir vazio mesmo com user concedendo Sono. Por isso pegamos as 3 fases
    // e o server agrega total = DEEP + REM + LIGHT.
    // Fix TF 60: incluímos SLEEP_IN_BED e SLEEP_AWAKE. Apple Watch SE / Watch
    // pré-Series 7 / modos de sleep schedule sem detection completa emitem
    // SOMENTE inBed. Sem esses tipos no request, plugin não retorna nada e
    // user vê "sem sono" mesmo dormindo com Watch. Server agrega total como:
    //   1) stages (deep+rem+light) se houver;
    //   2) fallback: inBed - awake;
    //   3) último recurso: sleep_hours legacy.
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.STEPS,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.RESPIRATORY_RATE,
    // Hidratação registrada no Health — comparável à prescrição diária do
    // plano (hydration por sessão). Tier rápido porque muda ao longo do dia.
    HealthDataType.WATER,
  ];

  /// Tier lento — consultado no máximo 1×/24h ([_lastSlowSyncKey]). Medidas
  /// corporais e atividade agregada mudam devagar; consultar a cada sync
  /// era o grosso dos ~7.6s de I/O HealthKit na abertura da home.
  static const _slowTypes = <HealthDataType>[
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.LEAN_BODY_MASS,
    HealthDataType.WAIST_CIRCUMFERENCE,
    HealthDataType.SKIN_TEMPERATURE,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.DISTANCE_CYCLING,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.EXERCISE_TIME,
    HealthDataType.APPLE_MOVE_TIME,
    HealthDataType.APPLE_STAND_TIME,
    HealthDataType.WALKING_SPEED,
    HealthDataType.WALKING_HEART_RATE,
  ];

  static const _types = <HealthDataType>[..._fastTypes, ..._slowTypes];

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
      // Throttle 24h: o breakdown itera hasPermissions tipo-por-tipo; rodar
      // em toda abertura só repete o mesmo dado no analytics.
      final lastLog = await _readDateFlag(_lastBreakdownLogKey);
      if (lastLog == null ||
          DateTime.now().difference(lastLog) > const Duration(hours: 24)) {
        await _saveDateFlag(_lastBreakdownLogKey, DateTime.now());
        unawaited(_logPermissionsBreakdown(stage: 'after_ensure'));
      }
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

  /// Status per-type das permissões granted no HK/HC. Versão pública do
  /// `_logPermissionsBreakdown` — usada pela UI de perfil/saúde pra mostrar
  /// checklist visual ao user (Sono ✓ / Batimentos ✓ / HRV ✗ etc).
  /// Chama N vezes `_health.hasPermissions([type])` — caro o suficiente pra
  /// rodar só em demanda (botão "VERIFICAR"), nunca no initState.
  ///
  /// ATENÇÃO: iOS retorna sempre null/false pra read permissions (privacy
  /// by design — Apple não confirma quais permissions de saúde foram
  /// granted, pra evitar deduzir condições). Use [permissionsBreakdownFromSamples]
  /// no iOS pra resultados confiáveis via proxy de query.
  // Tipos exclusivos do Apple HealthKit — não existem no Health Connect.
  // Filtrados do breakdown no Android pra evitar entradas sempre-falsas.
  static const _iosOnlyTypes = <HealthDataType>{
    HealthDataType.APPLE_MOVE_TIME,
    HealthDataType.APPLE_STAND_TIME,
  };

  Future<Map<String, bool>> permissionsBreakdown() async {
    if (!isSupported) return const {};
    final granted = <String, bool>{};
    for (final t in _types) {
      if (!kIsWeb && Platform.isAndroid && _iosOnlyTypes.contains(t)) continue;
      try {
        final ok = await _health.hasPermissions([t], permissions: [HealthDataAccess.READ]);
        granted[_typeMap[t] ?? t.name] = ok ?? false;
      } catch (_) {
        granted[_typeMap[t] ?? t.name] = false;
      }
    }
    return granted;
  }

  /// Status per-type aproximado via "tem sample nos últimos 7d?". Bypass
  /// pra quirk de iOS onde `hasPermissions` SEMPRE retorna null/false pra
  /// read permissions (privacy by design Apple). Quando user tem permissão
  /// + dado nos últimos 7d, o query retorna >0 samples = ✓.
  ///
  /// Limitação assumida: ✗ é AMBÍGUO — pode ser permission denied OU
  /// sem dado disponível no período (ex: user nunca registrou SpO2). A UI
  /// que consome esse método deixa essa ambiguidade explícita no subtítulo.
  ///
  /// Custo: ~200ms × N tipos via getHealthDataFromTypes = ~2s nos 12 tipos.
  /// Aceitável só em demanda (botão VERIFICAR).
  Future<Map<String, bool>> permissionsBreakdownFromSamples() async {
    if (!isSupported) return const {};
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 7));
    final result = <String, bool>{};
    for (final t in _types) {
      try {
        final samples = await _health.getHealthDataFromTypes(
          startTime: from,
          endTime: to,
          types: [t],
        );
        result[_typeMap[t] ?? t.name] = samples.isNotEmpty;
      } catch (_) {
        result[_typeMap[t] ?? t.name] = false;
      }
    }
    return result;
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
  ///
  /// Backfill one-time: clientes mais velhos sincronizaram com servidores
  /// que rejeitavam sleep_rem/sleep_light/etc no Zod. Os samples vieram do
  /// HK mas o batch ingest falhou; `_lastSync` foi atualizado mesmo assim,
  /// deixando esses dados "perdidos" pra sempre da perspectiva do app.
  /// Detectamos pela ausência da flag `biometrics_backfill_v1`: se faltar,
  /// força from=30d e seta a flag. Próximos syncs voltam ao normal.
  Future<int> syncSince([DateTime? since]) async {
    if (!isSupported) return 0;
    DateTime? effectiveSince = since;
    if (effectiveSince == null) {
      final box = Hive.isBoxOpen(_hiveBoxName)
          ? Hive.box<dynamic>(_hiveBoxName)
          : await Hive.openBox<dynamic>(_hiveBoxName);
      final backfillDone = box.get(_backfillFlagKey) == true;
      if (!backfillDone) {
        effectiveSince = DateTime.now().subtract(const Duration(days: 30));
        await box.put(_backfillFlagKey, true);
        analytics.logEvent('wearable_backfill_triggered', params: const {
          'window_days': 30,
        });
      }
    }
    // BUG histórico: `_readLastSync` era usado DIRETO como `startTime`. O
    // plugin `health` retorna só samples com `dateFrom >= startTime`. Sono
    // começa ANTES do lastSync (user dormiu 23h, syncou 23:30 → next sync
    // de manhã com lastSync=23:30 perde o sono inteiro, dateFrom 23h < 23:30).
    // Fix: subtrair 36h pra cobrir overnight sleep. Server dedupa por
    // `{type}_{recordedAt}` (doc id), então overlap é idempotente.
    final lastSync = await _readLastSync();
    final from = effectiveSince
        ?? (lastSync != null
            ? lastSync.subtract(const Duration(hours: 36))
            : DateTime.now().subtract(const Duration(days: 7)));
    final to = DateTime.now();

    // Tier lento: medidas corporais/atividade agregada entram no máximo
    // 1×/24h. `since` explícito (backfill/forceFullResync) força tudo.
    final lastSlowSync = await _readDateFlag(_lastSlowSyncKey);
    final slowDue = since != null ||
        lastSlowSync == null ||
        to.difference(lastSlowSync) > const Duration(hours: 24);
    final slowFrom = effectiveSince
        ?? (lastSlowSync != null
            ? lastSlowSync.subtract(const Duration(hours: 36))
            : DateTime.now().subtract(const Duration(days: 7)));
    final queries = <HealthDataType, DateTime>{
      for (final t in _fastTypes) t: from,
      if (slowDue)
        for (final t in _slowTypes) t: slowFrom,
    };

    // Fix TF 63: query POR TIPO em vez de batch. O plugin `health` lança
    // exception no PRIMEIRO tipo unsupported (ex: HRV_RMSSD em iOS) e ABORTA
    // a query inteira — sleep_deep/rem/light nem chegam a ser processados.
    // Iterando, um tipo ruim não mata os outros.
    final raw = <HealthDataPoint>[];
    final perTypeErrors = <String>[];
    for (final q in queries.entries) {
      try {
        final batch = await _health.getHealthDataFromTypes(
          startTime: q.value,
          endTime: to,
          types: [q.key],
        );
        raw.addAll(batch);
      } catch (e) {
        final key = _typeMap[q.key] ?? q.key.name;
        perTypeErrors.add('$key:${e.toString().substring(0, e.toString().length.clamp(0, 80))}');
      }
    }
    if (raw.isEmpty && perTypeErrors.length == queries.length) {
      // Todos falharam — provavelmente permissão revogada ou platform bug.
      analytics.logEvent('wearable_sync_failed', params: {
        'stage': 'fetch_all_failed',
        'platform': _platformLabel,
        'provider': _sourceLabel,
      });
      unawaited(_ds.postSyncTelemetry(
        from: from, to: to, lastSync: lastSync,
        hkFetchedTotal: -1, mappedTotal: 0,
        byType: {'_error': perTypeErrors.length},
        errorMsg: perTypeErrors.take(3).join(' | '),
      ));
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
      if (slowDue) await _saveDateFlag(_lastSlowSyncKey, to);
      analytics.logEvent('wearable_sync_completed', params: {
        'platform': _platformLabel,
        'provider': _sourceLabel,
        'samples_saved': 0,
        'samples_fetched': raw.length,
        'slow_tier': slowDue ? 1 : 0,
        ...byType.map((k, v) => MapEntry('fetched_$k', v)),
        ...mappedByType.map((k, v) => MapEntry('mapped_$k', v)),
      });
      // Telemetry pro server logar o estado da sync (debug do "sono não atualiza").
      unawaited(_ds.postSyncTelemetry(
        from: from, to: to, lastSync: lastSync,
        hkFetchedTotal: raw.length, mappedTotal: 0,
        byType: byType, mappedByType: mappedByType,
      ));
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
    if (slowDue) await _saveDateFlag(_lastSlowSyncKey, to);
    analytics.logEvent('wearable_sync_completed', params: {
      'platform': _platformLabel,
      'provider': _sourceLabel,
      'samples_saved': totalSaved,
      'samples_fetched': raw.length,
      'failed_batches': failedBatches,
      'slow_tier': slowDue ? 1 : 0,
      ...byType.map((k, v) => MapEntry('fetched_$k', v)),
      ...mappedByType.map((k, v) => MapEntry('mapped_$k', v)),
    });
    unawaited(_ds.postSyncTelemetry(
      from: from, to: to, lastSync: lastSync,
      hkFetchedTotal: raw.length, mappedTotal: samples.length,
      byType: byType, mappedByType: mappedByType,
    ));
    return totalSaved;
  }

  /// Safety net: força janela de 7d ignorando lastSync. Usado quando a
  /// sync padrão retorna 0 samples de sono e o user reclama que sono não
  /// atualizou — bypass do bug "lastSync fresco demais".
  Future<int> forceFullResync() async {
    return syncSince(DateTime.now().subtract(const Duration(days: 7)));
  }

  BiometricSampleInput? _mapToInput(HealthDataPoint p) {
    final type = _typeMap[p.type];
    if (type == null) return null;
    final rawValue = p.value;
    var value = rawValue is NumericHealthValue
        ? rawValue.numericValue
        : double.tryParse(rawValue.toString());
    if (value == null) return null;

    // FIX CRÍTICO: pra SLEEP_*, o plugin `health` retorna o VALOR DE CATEGORIA
    // (HKCategoryValueSleepAnalysis enum: 3=light, 4=deep, 5=REM), NÃO a
    // duração. User reportou que dormiu 5h18 e o app mostrava 0.3h — porque
    // estavamos somando o int da categoria dividido por 60.
    // Solução correta: usar `dateTo - dateFrom` que dá a duração real do
    // sample em segundos → converter pra horas.
    if (p.type == HealthDataType.SLEEP_ASLEEP ||
        p.type == HealthDataType.SLEEP_DEEP ||
        p.type == HealthDataType.SLEEP_REM ||
        p.type == HealthDataType.SLEEP_LIGHT ||
        p.type == HealthDataType.SLEEP_IN_BED ||
        p.type == HealthDataType.SLEEP_AWAKE) {
      final durationS = p.dateTo.difference(p.dateFrom).inSeconds;
      value = durationS / 3600.0; // segundos → horas
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
    HealthDataType.SLEEP_REM: 'sleep_rem',
    HealthDataType.SLEEP_LIGHT: 'sleep_light',
    HealthDataType.SLEEP_IN_BED: 'sleep_in_bed',
    HealthDataType.SLEEP_AWAKE: 'sleep_awake',
    HealthDataType.STEPS: 'steps',
    HealthDataType.BLOOD_OXYGEN: 'spo2',
    HealthDataType.WEIGHT: 'weight',
    HealthDataType.ACTIVE_ENERGY_BURNED: 'calories_burned',
    HealthDataType.RESPIRATORY_RATE: 'respiratory_rate',
    HealthDataType.BASAL_ENERGY_BURNED: 'calories_basal',
    HealthDataType.WATER: 'water',
    HealthDataType.DISTANCE_WALKING_RUNNING: 'distance_walking_running',
    HealthDataType.DISTANCE_CYCLING: 'distance_cycling',
    HealthDataType.FLIGHTS_CLIMBED: 'flights_climbed',
    HealthDataType.EXERCISE_TIME: 'exercise_time',
    HealthDataType.APPLE_MOVE_TIME: 'apple_move_time',
    HealthDataType.APPLE_STAND_TIME: 'apple_stand_time',
    HealthDataType.WALKING_SPEED: 'walking_speed',
    HealthDataType.WALKING_HEART_RATE: 'walking_bpm',
    HealthDataType.HEIGHT: 'height',
    HealthDataType.BODY_FAT_PERCENTAGE: 'body_fat_pct',
    HealthDataType.BODY_MASS_INDEX: 'bmi',
    HealthDataType.LEAN_BODY_MASS: 'lean_body_mass',
    HealthDataType.WAIST_CIRCUMFERENCE: 'waist_circumference',
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 'hrv_rmssd',
    HealthDataType.SKIN_TEMPERATURE: 'skin_temperature',
  };

  static const _unitMap = <HealthDataType, String>{
    HealthDataType.HEART_RATE: 'bpm',
    HealthDataType.RESTING_HEART_RATE: 'bpm',
    HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'ms',
    HealthDataType.SLEEP_ASLEEP: 'hours',
    HealthDataType.SLEEP_DEEP: 'hours',
    HealthDataType.SLEEP_REM: 'hours',
    HealthDataType.SLEEP_LIGHT: 'hours',
    HealthDataType.SLEEP_IN_BED: 'hours',
    HealthDataType.SLEEP_AWAKE: 'hours',
    HealthDataType.STEPS: 'count',
    HealthDataType.BLOOD_OXYGEN: '%',
    HealthDataType.WEIGHT: 'kg',
    HealthDataType.ACTIVE_ENERGY_BURNED: 'kcal',
    HealthDataType.RESPIRATORY_RATE: 'rpm',
    HealthDataType.BASAL_ENERGY_BURNED: 'kcal',
    HealthDataType.WATER: 'liters',
    HealthDataType.DISTANCE_WALKING_RUNNING: 'm',
    HealthDataType.DISTANCE_CYCLING: 'm',
    HealthDataType.FLIGHTS_CLIMBED: 'count',
    HealthDataType.EXERCISE_TIME: 'min',
    HealthDataType.APPLE_MOVE_TIME: 'min',
    HealthDataType.APPLE_STAND_TIME: 'min',
    HealthDataType.WALKING_SPEED: 'm/s',
    HealthDataType.WALKING_HEART_RATE: 'bpm',
    HealthDataType.HEIGHT: 'm',
    HealthDataType.BODY_FAT_PERCENTAGE: '%',
    HealthDataType.BODY_MASS_INDEX: 'kg/m2',
    HealthDataType.LEAN_BODY_MASS: 'kg',
    HealthDataType.WAIST_CIRCUMFERENCE: 'm',
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD: 'ms',
    HealthDataType.SKIN_TEMPERATURE: 'celsius',
  };

  Future<DateTime?> _readLastSync() => _readDateFlag(_lastSyncKey);

  Future<void> _saveLastSync(DateTime ts) => _saveDateFlag(_lastSyncKey, ts);

  Future<DateTime?> _readDateFlag(String key) async {
    if (!Hive.isBoxOpen(_hiveBoxName)) return null;
    final raw = Hive.box<dynamic>(_hiveBoxName).get(key);
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Future<void> _saveDateFlag(String key, DateTime ts) async {
    final box = Hive.isBoxOpen(_hiveBoxName)
        ? Hive.box<dynamic>(_hiveBoxName)
        : await Hive.openBox<dynamic>(_hiveBoxName);
    await box.put(key, ts.toIso8601String());
  }
}

final healthSyncService = HealthSyncService();
