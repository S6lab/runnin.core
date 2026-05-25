import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

class PlanRemoteDatasource {
  final Dio _dio;
  PlanRemoteDatasource() : _dio = apiClient;

  // Guard contra disparos simultâneos de generatePlan. Antes: hard refresh
  // ou clique duplo no botão "GERAR PLANO" disparava 2 POSTs paralelos; o
  // server retornava 409 no segundo (race do checkout no Firestore). Era
  // inofensivo mas ruidoso nos logs e confundia o user (toast de erro).
  static bool _generateInFlight = false;

  // ── Cache do plano (Hive) ──────────────────────────────────────────────
  // Recuperado no login e reusado pelas telas. Invalida só quando: (1) o user
  // gera/regenera um plano, (2) aplica checkpoint/revisão, ou (3) cruza um
  // domingo desde o cache (atualização automática do coach roda aos domingos).
  static const _boxName = 'runnin_settings';
  static const _planKey = 'cached_plan_json';
  static const _planAtKey = 'cached_plan_at';

  Box<dynamic>? get _box =>
      Hive.isBoxOpen(_boxName) ? Hive.box<dynamic>(_boxName) : null;

  /// Lê o plano do cache local (sync). Null se não há cache ou está stale.
  Plan? readCachedPlan({bool ignoreStale = false}) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get(_planKey);
    if (raw is! String || raw.isEmpty) return null;
    if (!ignoreStale) {
      final at = DateTime.tryParse(box.get(_planAtKey) as String? ?? '');
      if (at == null || _staleBySunday(at)) return null;
    }
    try {
      return Plan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void _writeCache(Map<String, dynamic> json) {
    _box?.put(_planKey, jsonEncode(json));
    _box?.put(_planAtKey, DateTime.now().toIso8601String());
  }

  /// Limpa o cache do plano. Chamar ao gerar/regenerar ou aplicar
  /// checkpoint/revisão (o plano mudou no servidor).
  static void clearPlanCache() {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box<dynamic>(_boxName);
    box.delete(_planKey);
    box.delete(_planAtKey);
  }

  /// Stale se o cache foi gravado ANTES do domingo mais recente — assim a
  /// atualização automática do coach (domingos) é puxada do servidor.
  static bool _staleBySunday(DateTime cachedAt) {
    final now = DateTime.now();
    final daysSinceSunday = now.weekday % 7; // Dom=0, Seg=1 ... Sáb=6
    final lastSunday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysSinceSunday));
    return cachedAt.isBefore(lastSunday);
  }

  /// [cacheFirst]: se true e houver cache fresco, retorna sem rede (usado em
  /// telas que querem exibição instantânea, ex: home). Default = rede (sempre
  /// busca o servidor e atualiza o cache).
  Future<Plan?> getCurrentPlan({bool cacheFirst = false}) async {
    if (cacheFirst) {
      final cached = readCachedPlan();
      if (cached != null) return cached;
    }
    try {
      final res = await _dio.get('/plans/current');
      final data = res.data as Map<String, dynamic>;
      _writeCache(data);
      return Plan.fromJson(data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        clearPlanCache(); // não há plano ativo
        return null;
      }
      if (statusCode == 401) return null;
      // Erro de rede: usa cache (mesmo stale) pra não travar a UI offline.
      final cached = readCachedPlan(ignoreStale: true);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<String> generatePlan({
    required String goal,
    required String level,
    int? frequency,
    int? weeksCount,
    String? startDate, // ISO YYYY-MM-DD; D0 escolhida no onboarding
    bool confirmOverwrite = false,
    /// Matiz fino do nível dentro de 'iniciante' (jornada nova de criação:
    /// 'nunca_corri' | 'esporadico' | 'iniciante_freq'). Server usa no prompt.
    String? levelHint,
    /// Volume atual em km/sem (vem da tela 05, prefill via /stats/breakdown).
    double? currentWeeklyKm,
    /// Pace atual confortável (M:SS/km), tela 05.
    String? currentPaceMinKm,
    /// Dias da semana disponíveis pra treinar (1=seg…7=dom).
    List<int>? availableDays,
    /// Tipo de objetivo: 'flow' (sem prova) ou 'race' (com meta de prova).
    /// Quando ausente, server cai no caminho legado (parsing por `goal`).
    String? goalKind,
    /// Sub-meta dentro de FLOW: 'start' | 'improve' | 'injury_return' | 'postpartum'.
    String? flowSubgoal,
    /// Distância da prova (5, 10, 21, 42) quando goalKind=race.
    int? raceDistanceKm,
    /// Modo da meta race: 'complete' (só terminar) ou 'improve_pace' (bater pace alvo).
    String? raceMode,
    /// Pace alvo M:SS/km (só raceMode=improve_pace).
    String? targetPaceMinKm,
    /// Data da prova/alvo ISO YYYY-MM-DD.
    String? raceDate,
    /// Dia preferido pro long run (1=seg…7=dom).
    int? longRunDayOfWeek,
    /// Tempo máximo disponível pro long run em min. Coach cap a distância.
    int? longRunMaxMinutes,
  }) async {
    if (_generateInFlight) {
      // ignore: avoid_print
      print('plan.generate.skipped reason=in_flight');
      throw DioException(
        requestOptions: RequestOptions(path: '/plans/generate'),
        message: 'Geração já em andamento — aguarda a primeira terminar.',
        type: DioExceptionType.cancel,
      );
    }
    _generateInFlight = true;
    try {
      final res = await _dio.post(
        '/plans/generate',
        queryParameters: confirmOverwrite ? {'confirmOverwrite': '1'} : null,
        data: {
          'goal': goal,
          'level': level,
          'weeksCount': ?weeksCount,
          'frequency': ?frequency,
          'startDate': ?startDate,
          'levelHint': ?levelHint,
          'currentWeeklyKm': ?currentWeeklyKm,
          'currentPaceMinKm': ?currentPaceMinKm,
          'availableDays': ?availableDays,
          'goalKind': ?goalKind,
          'flowSubgoal': ?flowSubgoal,
          'raceDistanceKm': ?raceDistanceKm,
          'raceMode': ?raceMode,
          'targetPaceMinKm': ?targetPaceMinKm,
          'raceDate': ?raceDate,
          'longRunDayOfWeek': ?longRunDayOfWeek,
          'longRunMaxMinutes': ?longRunMaxMinutes,
        },
      );
      // Plano novo no servidor — invalida o cache pra forçar refetch.
      clearPlanCache();
      return (res.data as Map<String, dynamic>)['planId'] as String;
    } finally {
      _generateInFlight = false;
    }
  }

  Future<Plan> getPlanById(String planId) async {
    final res = await _dio.get('/plans/$planId');
    return Plan.fromJson(res.data as Map<String, dynamic>);
  }
}
