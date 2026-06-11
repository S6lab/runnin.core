/// Motor de admissibilidade do plano — espelho client-side das regras que o
/// server roda em `server/src/modules/plans/use-cases/validate-*.ts`.
///
/// Roda no FE antes do `_submit` pra evitar que o user clique "GERAR PLANO"
/// e bata num 422 técnico. Quando inadmissível, retorna issues + sugestões
/// estruturadas pra UI montar um BottomSheet com botões de ação.
///
/// IMPORTANTE: manter em sync com `server/.../plan-windows.constants.ts`.
/// Mudar o pico/cap/janela aqui sem mudar lá causa falsos positivos.
library;

// ─── Constantes (MIRROR de server/.../plan-windows.constants.ts) ────────────

/// Janelas em semanas por (distância × nível). null = REDIRECT (server
/// bloqueia). Re-export do `RaceWindowsTable` que já vive em
/// `steps/step_race_extras.dart` pra reduzir duplicação.
class RaceWindowRow {
  final int? aggressive;
  final int? feasible;
  final int safe;
  const RaceWindowRow(this.aggressive, this.feasible, this.safe);
}

class AdmissibilityConstants {
  /// Tabelas mutáveis: os literais abaixo são o FALLBACK hardcoded (espelho
  /// do server no momento do build). `applyRemoteConfig` sobrescreve com o
  /// payload de GET /plans/admissibility-config no open do wizard — a fonte
  /// única passa a ser o server, sem release do app pra mudar regra.
  static Map<int, Map<String, RaceWindowRow>> raceWindows = <int, Map<String, RaceWindowRow>>{
    5: {
      'iniciante':     RaceWindowRow(8, 10, 12),
      'intermediario': RaceWindowRow(6, 8, 10),
      'avancado':      RaceWindowRow(6, 6, 8),
    },
    10: {
      'iniciante':     RaceWindowRow(10, 12, 14),
      'intermediario': RaceWindowRow(8, 10, 12),
      'avancado':      RaceWindowRow(6, 8, 10),
    },
    21: {
      'iniciante':     RaceWindowRow(null, 16, 20),
      'intermediario': RaceWindowRow(12, 14, 18),
      'avancado':      RaceWindowRow(10, 12, 14),
    },
    42: {
      'iniciante':     RaceWindowRow(null, null, 26),
      'intermediario': RaceWindowRow(16, 18, 22),
      'avancado':      RaceWindowRow(14, 16, 20),
    },
  };

  /// 5K skip volume check (entry point).
  static Map<int, int> peakWeeklyKm = <int, int>{5: 0, 10: 18, 21: 32, 42: 45};

  /// Sentinel: distância bloqueada pra esse subnível (não importa freq).
  static const int blockedByLevel = 9999;

  /// MIN sessões/sem por (subnível × distância). Subnível = combinação
  /// de `level` (backend) + `levelHint` (refinamento do iniciante). Veja
  /// `resolveProfileKey()`.
  ///
  /// MIRROR de server/.../plan-windows.constants.ts: MIN_FREQ_BY_PROFILE_DISTANCE.
  static Map<String, Map<int, int>> minFreqByProfileDistance = <String, Map<int, int>>{
    'iniciante_nunca': {5: 2, 10: 3, 21: blockedByLevel, 42: blockedByLevel},
    'iniciante_esp':   {5: 2, 10: 3, 21: blockedByLevel, 42: blockedByLevel},
    'iniciante_freq':  {5: 2, 10: 3, 21: 4, 42: blockedByLevel},
    'intermediario':   {5: 2, 10: 3, 21: 3, 42: 4},
    'avancado':        {5: 2, 10: 3, 21: 3, 42: 4},
  };

  /// Restrições estáticas de window por (subnível × distância). null = sem
  /// restrição (todas as 3 janelas permitidas).
  static Map<String, Map<int, List<String>>> windowRestrictionByProfile = <String, Map<int, List<String>>>{
    'iniciante_nunca': {10: ['safe']},
    'iniciante_esp':   {10: ['safe']},
  };

  /// Bypass de improve_pace por nível backend → distâncias liberadas
  /// totalmente. Iniciante (qualquer subtipo) NÃO está aqui.
  static Map<String, List<int>> improvePaceBypassByLevel = <String, List<int>>{
    'intermediario': [5, 10],
    'avancado':      [5, 10, 21, 42],
  };

  /// Resolve "subnível composto" combinando level + levelHint.
  static String resolveProfileKey(String level, String? levelHint) {
    if (level == 'intermediario') return 'intermediario';
    if (level == 'avancado') return 'avancado';
    if (levelHint == 'nunca_corri') return 'iniciante_nunca';
    if (levelHint == 'esporadico') return 'iniciante_esp';
    return 'iniciante_freq';
  }

  /// Freq mínima pra (level, distance, levelHint). Retorna blockedByLevel
  /// quando a combinação é proibida.
  static int minFreqFor(String level, int distance, {String? levelHint}) {
    final key = resolveProfileKey(level, levelHint);
    final byProfile = minFreqByProfileDistance[key] ?? minFreqByProfileDistance['iniciante_freq']!;
    return byProfile[distance] ?? 2;
  }

  /// True se atleta tem bypass total de freq/window pra essa distância
  /// quando em modo improve_pace.
  static bool hasImprovePaceBypass(String level, int distance) {
    return improvePaceBypassByLevel[level]?.contains(distance) ?? false;
  }

  /// Lista de modos de janela permitidos. null = sem restrição.
  /// Considera restrição estática + dinâmica (intermediario+21K+freq=3).
  static List<String>? getAllowedWindows(
    String level,
    int distance,
    int frequency, {
    String? levelHint,
  }) {
    final key = resolveProfileKey(level, levelHint);
    final staticRestriction = windowRestrictionByProfile[key]?[distance];
    if (staticRestriction != null) return staticRestriction;
    if (key == 'intermediario' && distance == 21 && frequency == 3) {
      return ['safe'];
    }
    return null;
  }

  /// Cap km/sessão por nível (long run máximo).
  static Map<String, int> maxKmPerSession = <String, int>{
    'iniciante': 14,
    'intermediario': 22,
    'avancado': 32,
  };

  /// Subdistância sugerida quando bloqueia. null = sem subdistância.
  static Map<int, int?> redirectTarget = <int, int?>{5: null, 10: 5, 21: 10, 42: 21};

  /// Crescimento semanal sustentável (regra dos 10%).
  static double weeklyRampRate = 1.10;

  /// Base mínima (walk-run permite 5km/sem desde sem 1).
  static int rampBaseFloorKm = 5;

  /// Comorbidades sérias — match substring case+diacritic insensitive.
  static List<String> seriousMedicalKeywords = <String>[
    'cirurgia', 'hernia', 'anticoagulante', 'insulina',
    'cardiac', 'cardio', 'avc', 'lesao recente',
  ];

  /// Faixas etárias com restrição de janela.
  static int blockAggressiveAge = 55;       // ≥55 + 42K → ≥feasible
  static int forceFeasibleHalfAge = 65;     // ≥65 + 21K → ≥feasible
  static int forceSafeMarathonAge = 65;     // ≥65 + 42K → safe

  /// Ceiling de ganho % pace por nível em 12 sem (escala 0.5x..1.5x).
  static Map<String, double> paceImprovementCeilingPct = <String, double>{
    'iniciante': 8.0,
    'intermediario': 5.0,
    'avancado': 3.0,
  };

  /// Versão do config aplicado (null = só fallback local).
  static int? appliedConfigVersion;

  /// Sobrescreve as tabelas com o payload de GET /plans/admissibility-config.
  /// Parse defensivo campo a campo: qualquer pedaço malformado mantém o
  /// fallback daquele pedaço (nunca deixa o motor sem regra).
  static void applyRemoteConfig(Map<String, dynamic> json) {
    if (json['version'] != 1) return; // shape desconhecido → fallback total

    Map<int, Map<String, RaceWindowRow>>? windows;
    final rw = json['raceWindows'];
    if (rw is Map) {
      windows = {};
      for (final e in rw.entries) {
        final dist = int.tryParse(e.key.toString());
        final byLevel = e.value;
        if (dist == null || byLevel is! Map) continue;
        final levelMap = <String, RaceWindowRow>{};
        for (final le in byLevel.entries) {
          final v = le.value;
          if (v is! Map) continue;
          final safe = (v['safe'] as num?)?.toInt();
          if (safe == null) continue;
          levelMap[le.key.toString()] = RaceWindowRow(
            (v['aggressive'] as num?)?.toInt(),
            (v['feasible'] as num?)?.toInt(),
            safe,
          );
        }
        if (levelMap.isNotEmpty) windows[dist] = levelMap;
      }
    }
    if (windows != null && windows.isNotEmpty) raceWindows = windows;

    Map<int, int>? intIntMap(dynamic raw) {
      if (raw is! Map) return null;
      final out = <int, int>{};
      for (final e in raw.entries) {
        final k = int.tryParse(e.key.toString());
        final v = (e.value as num?)?.toInt();
        if (k != null && v != null) out[k] = v;
      }
      return out.isEmpty ? null : out;
    }

    final peak = intIntMap(json['peakWeeklyKm']);
    if (peak != null) peakWeeklyKm = peak;

    final minFreq = json['minFreqByProfileDistance'];
    if (minFreq is Map) {
      final out = <String, Map<int, int>>{};
      for (final e in minFreq.entries) {
        final inner = intIntMap(e.value);
        if (inner != null) out[e.key.toString()] = inner;
      }
      if (out.isNotEmpty) minFreqByProfileDistance = out;
    }

    final winRestr = json['windowRestrictionByProfile'];
    if (winRestr is Map) {
      final out = <String, Map<int, List<String>>>{};
      for (final e in winRestr.entries) {
        final byDist = e.value;
        if (byDist is! Map) continue;
        final inner = <int, List<String>>{};
        for (final de in byDist.entries) {
          final k = int.tryParse(de.key.toString());
          final v = de.value;
          if (k != null && v is List) inner[k] = v.map((x) => x.toString()).toList();
        }
        out[e.key.toString()] = inner;
      }
      windowRestrictionByProfile = out;
    }

    final bypass = json['improvePaceBypassByLevel'];
    if (bypass is Map) {
      final out = <String, List<int>>{};
      for (final e in bypass.entries) {
        final v = e.value;
        if (v is List) {
          out[e.key.toString()] =
              v.map((x) => (x as num).toInt()).toList();
        }
      }
      if (out.isNotEmpty) improvePaceBypassByLevel = out;
    }

    final caps = json['maxKmPerSession'];
    if (caps is Map) {
      final out = <String, int>{};
      for (final e in caps.entries) {
        final v = (e.value as num?)?.toInt();
        if (v != null) out[e.key.toString()] = v;
      }
      if (out.isNotEmpty) maxKmPerSession = out;
    }

    final redirect = json['redirectTarget'];
    if (redirect is Map) {
      final out = <int, int?>{};
      for (final e in redirect.entries) {
        final k = int.tryParse(e.key.toString());
        if (k != null) out[k] = (e.value as num?)?.toInt();
      }
      if (out.isNotEmpty) redirectTarget = out;
    }

    final ramp = (json['weeklyRampRate'] as num?)?.toDouble();
    if (ramp != null && ramp > 1.0 && ramp < 2.0) weeklyRampRate = ramp;
    final floor = (json['rampBaseFloorKm'] as num?)?.toInt();
    if (floor != null && floor > 0) rampBaseFloorKm = floor;

    final age = json['ageRestrictionThresholds'];
    if (age is Map) {
      blockAggressiveAge = (age['blockAggressiveAge'] as num?)?.toInt() ?? blockAggressiveAge;
      forceFeasibleHalfAge = (age['forceFeasibleHalfAge'] as num?)?.toInt() ?? forceFeasibleHalfAge;
      forceSafeMarathonAge = (age['forceSafeMarathonAge'] as num?)?.toInt() ?? forceSafeMarathonAge;
    }

    final pace = json['paceImprovementCeilingPct'];
    if (pace is Map) {
      final out = <String, double>{};
      for (final e in pace.entries) {
        final v = (e.value as num?)?.toDouble();
        if (v != null) out[e.key.toString()] = v;
      }
      if (out.isNotEmpty) paceImprovementCeilingPct = out;
    }

    // Labels canônicos sérios entram como keywords extras (match exato
    // normalizado vira substring match — labels são específicos o bastante).
    final medOptions = json['medicalConditionOptions'];
    if (medOptions is List) {
      final extra = <String>[];
      for (final o in medOptions) {
        if (o is Map && o['serious'] == true && o['label'] is String) {
          extra.add(_normalize(o['label'] as String));
        }
      }
      if (extra.isNotEmpty) {
        seriousMedicalKeywords = {...seriousMedicalKeywords, ...extra}.toList();
      }
    }

    appliedConfigVersion = (json['version'] as num).toInt();
  }
}

// ─── Input state ───────────────────────────────────────────────────────────

/// Snapshot do que o user montou no wizard até agora. Subset dos campos do
/// PlanSetupPage. Campos nullable = "não preenchido ainda".
class AdmissibilityState {
  final String? goalKind;        // 'flow' | 'race'
  final String? flowSubgoal;     // 'start' | 'improve' | 'injury_return' | 'postpartum'
  final int? raceDistanceKm;     // 5 | 10 | 21 | 42
  final String? raceMode;        // 'complete' | 'improve_pace'
  final String? targetPaceMinKm; // M:SS/km
  final String? currentPaceMinKm;// M:SS/km
  final String? level;           // 'iniciante' | 'intermediario' | 'avancado'
  /// Refinamento do iniciante: 'nunca_corri' | 'esporadico' | 'iniciante_freq'.
  /// Pra intermediário/avancado é null (só level define).
  final String? levelHint;
  final int? frequency;
  final int availableDaysCount;
  final double? currentWeeklyKm;
  final int? weeksCount;         // janela escolhida (do step_window/race_date)
  final String? windowMode;      // 'aggressive' | 'feasible' | 'safe'
  final String? birthDate;       // ISO YYYY-MM-DD
  final List<String> medicalConditions;
  final List<String> goalKindSuggestionsToAvoid; // pra recursão (não usado por ora)

  const AdmissibilityState({
    this.goalKind,
    this.flowSubgoal,
    this.raceDistanceKm,
    this.raceMode,
    this.targetPaceMinKm,
    this.currentPaceMinKm,
    this.level,
    this.levelHint,
    this.frequency,
    this.availableDaysCount = 0,
    this.currentWeeklyKm,
    this.weeksCount,
    this.windowMode,
    this.birthDate,
    this.medicalConditions = const [],
    this.goalKindSuggestionsToAvoid = const [],
  });
}

// ─── Issues ────────────────────────────────────────────────────────────────

sealed class AdmissibilityIssue {
  String get explanation;
}

class FrequencyTooLow extends AdmissibilityIssue {
  final int minRequired;
  final int current;
  final int distanceKm;
  FrequencyTooLow({required this.minRequired, required this.current, required this.distanceKm});
  @override
  String get explanation =>
      'Pra ${distanceKm}K, mínimo $minRequired treinos/sem. Você marcou $current.';
}

/// Combinação (level, distance, levelHint) bloqueada por nível — não é
/// possível desbloquear aumentando freq. Server retorna 422 com sentinel
/// minFreq == BLOCKED_BY_LEVEL.
class LevelBlockedForDistance extends AdmissibilityIssue {
  final int distanceKm;
  final String? levelHint;
  final String level;
  LevelBlockedForDistance({
    required this.distanceKm,
    required this.level,
    required this.levelHint,
  });
  @override
  String get explanation {
    if (distanceKm == 42) {
      return 'Maratona pede base de intermediário/avançado. Começa com uma '
          'distância menor como Fase 1.';
    }
    if (distanceKm == 21) {
      if (levelHint == 'nunca_corri') {
        return 'Meia maratona precisa de base — quem nunca correu começa com 5K ou 10K.';
      }
      if (levelHint == 'esporadico') {
        return 'Meia maratona precisa de base — corridas esporádicas pedem 5K ou 10K primeiro.';
      }
    }
    return '${distanceKm}K não está liberado pra você. Tenta uma distância menor.';
  }
}

/// Janela escolhida não é permitida pra esse (subnível × distância).
/// Ex: nunca_corri + 10K só permite 'safe'. Intermediário + 21K + freq=3
/// também só permite 'safe'.
class WindowNotAllowedForProfile extends AdmissibilityIssue {
  final int distanceKm;
  final String chosenWindow;
  final List<String> allowedWindows;
  WindowNotAllowedForProfile({
    required this.distanceKm,
    required this.chosenWindow,
    required this.allowedWindows,
  });
  @override
  String get explanation {
    final allowedLabel = allowedWindows.map((w) {
      if (w == 'safe') return 'SEGURA';
      if (w == 'feasible') return 'FACTÍVEL';
      return 'AGRESSIVA';
    }).join(' / ');
    return 'Pra ${distanceKm}K nesse perfil, janela $allowedLabel é a permitida.';
  }
}

class SessionVolumeTooHigh extends AdmissibilityIssue {
  final int capKmPerSession;
  final double projectedKmPerSession;
  final int minFreqRequired;
  final String level;
  SessionVolumeTooHigh({
    required this.capKmPerSession,
    required this.projectedKmPerSession,
    required this.minFreqRequired,
    required this.level,
  });
  @override
  String get explanation =>
      'Com essa freq, cada sessão fica ~${projectedKmPerSession.toStringAsFixed(0)}km. '
      'Cap pra $level é ${capKmPerSession}km/sessão. Precisa de pelo menos '
      '$minFreqRequired treinos/sem nessa distância.';
}

class VolumeRampInsufficient extends AdmissibilityIssue {
  final int requiredPeakKm;
  final double rampedKm;
  final int distanceKm;
  final int weeksCount;
  final int? redirectTo;
  VolumeRampInsufficient({
    required this.requiredPeakKm,
    required this.rampedKm,
    required this.distanceKm,
    required this.weeksCount,
    required this.redirectTo,
  });
  @override
  String get explanation =>
      'Pra ${distanceKm}K precisa rampar até ${requiredPeakKm}km/sem. '
      'Seu volume atual em $weeksCount sem só sobe pra ~${rampedKm.toStringAsFixed(0)}km/sem.';
}

class AgeRestriction extends AdmissibilityIssue {
  final int age;
  final int distanceKm;
  final String recommendedMinWindow; // 'feasible' | 'safe'
  AgeRestriction({required this.age, required this.distanceKm, required this.recommendedMinWindow});
  @override
  String get explanation =>
      'Aos $age anos pra ${distanceKm}K, recomendamos janela '
      '${recommendedMinWindow == 'safe' ? 'SEGURA' : 'FACTÍVEL'} no mínimo.';
}

class MedicalRestriction extends AdmissibilityIssue {
  final List<String> matchedConditions;
  final String reason; // 'serious_condition' | 'multiple_conditions'
  MedicalRestriction({required this.matchedConditions, required this.reason});
  @override
  String get explanation {
    if (reason == 'serious_condition') {
      return 'Suas condições (${matchedConditions.join(', ')}) pedem janela SEGURA.';
    }
    return 'Você marcou ${matchedConditions.length} condições — recomendamos janela SEGURA.';
  }
}

class PaceTargetTooAmbitious extends AdmissibilityIssue {
  final double maxImprovementPct;
  final String suggestedTargetPace;
  PaceTargetTooAmbitious({required this.maxImprovementPct, required this.suggestedTargetPace});
  @override
  String get explanation =>
      'Ganho pedido é maior que o factível pro seu nível. '
      'Máximo ~${maxImprovementPct.toStringAsFixed(0)}% — sugerido: $suggestedTargetPace/km.';
}

// ─── Suggestions ───────────────────────────────────────────────────────────

sealed class AdmissibilitySuggestion {
  String get label;
  String get subtitle;
}

class IncreaseFrequency extends AdmissibilitySuggestion {
  final int toN;
  IncreaseFrequency(this.toN);
  @override
  String get label => 'Aumentar pra $toN treinos/sem';
  @override
  String get subtitle => 'Mantém a meta, ajusta os dias.';
}

class SwitchDistance extends AdmissibilitySuggestion {
  final int toKm;
  SwitchDistance(this.toKm);
  @override
  String get label => 'Trocar pra ${toKm}K (Fase 1)';
  @override
  String get subtitle => 'Cabe na sua disponibilidade atual. Depois rampamos.';
}

class SwitchToSafeWindow extends AdmissibilitySuggestion {
  final int weeks;
  SwitchToSafeWindow(this.weeks);
  @override
  String get label => 'Ir pra janela SEGURA ($weeks sem)';
  @override
  String get subtitle => 'Mais tempo de preparação, mais folga.';
}

class RelaxPaceTarget extends AdmissibilitySuggestion {
  final String toPace;
  RelaxPaceTarget(this.toPace);
  @override
  String get label => 'Aceitar pace alvo $toPace/km';
  @override
  String get subtitle => 'Limite factível pelo seu nível na janela escolhida.';
}

class SwitchToCompleteMode extends AdmissibilitySuggestion {
  @override
  String get label => 'Tirar pace alvo (só completar)';
  @override
  String get subtitle => 'Sem cobrança de tempo na chegada.';
}

class SwitchToFlow extends AdmissibilitySuggestion {
  @override
  String get label => 'Mudar pra FLOW (treinar sem prova)';
  @override
  String get subtitle => 'Foco em consistência. Coach propõe metas via checkpoints.';
}

// ─── Result + check ────────────────────────────────────────────────────────

class AdmissibilityResult {
  final bool ok;
  final List<AdmissibilityIssue> issues;
  final List<AdmissibilitySuggestion> suggestions;
  const AdmissibilityResult({required this.ok, required this.issues, required this.suggestions});

  static const ok_ = AdmissibilityResult(ok: true, issues: [], suggestions: []);
}

String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[áàâã]'), 'a').replaceAll(RegExp(r'[éèê]'), 'e')
        .replaceAll(RegExp(r'[íì]'), 'i').replaceAll(RegExp(r'[óòôõ]'), 'o')
        .replaceAll(RegExp(r'[úù]'), 'u').replaceAll('ç', 'c');

int? _computeAge(String? birthDate, [DateTime? today]) {
  if (birthDate == null || birthDate.isEmpty) return null;
  today ??= DateTime.now();
  DateTime? d;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(birthDate)) {
    d = DateTime.tryParse(birthDate);
  } else if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(birthDate)) {
    final p = birthDate.split('/');
    d = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
  }
  if (d == null) return null;
  var age = today.year - d.year;
  if (today.month < d.month || (today.month == d.month && today.day < d.day)) age--;
  return age;
}

int? _parsePaceSec(String p) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(p);
  if (m == null) return null;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

String _formatPace(int secPerKm) {
  final m = secPerKm ~/ 60;
  final s = secPerKm % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Roda todas as regras client-side. Retorna ok ou lista de issues +
/// sugestões pra UI montar bottom sheet. FLOW retorna sempre ok (a menos
/// que faltem dados críticos — esses são pegos pelo `_canProceed` do
/// wizard, não pelo motor).
AdmissibilityResult checkAdmissibility(AdmissibilityState s) {
  // FLOW: motor não bloqueia (FLOW é flexível por design).
  if (s.goalKind != 'race') return AdmissibilityResult.ok_;
  if (s.raceDistanceKm == null || s.level == null) return AdmissibilityResult.ok_;
  final dist = s.raceDistanceKm!;
  final level = s.level!;

  final issues = <AdmissibilityIssue>[];

  // 0. Bypass total de improve_pace pra (level × distance) elegíveis.
  //    Avançado: qualquer distância. Intermediário: só 5K/10K. Iniciante: nunca.
  final isImprovePaceBypassed = s.raceMode == 'improve_pace' &&
      AdmissibilityConstants.hasImprovePaceBypass(level, dist);

  // 1. Frequency + level block — matriz por (subnível × distância).
  //    Pula tudo se bypass. Sentinel BLOCKED_BY_LEVEL = combinação proibida
  //    por LEVEL (não dá pra resolver com mais freq).
  final freq = s.frequency ?? 0;
  if (!isImprovePaceBypassed) {
    final minFreq = AdmissibilityConstants.minFreqFor(
      level, dist,
      levelHint: s.levelHint,
    );
    if (minFreq >= AdmissibilityConstants.blockedByLevel) {
      issues.add(LevelBlockedForDistance(
        distanceKm: dist,
        level: level,
        levelHint: s.levelHint,
      ));
    } else if (freq < minFreq) {
      issues.add(FrequencyTooLow(minRequired: minFreq, current: freq, distanceKm: dist));
    } else {
      final peak = AdmissibilityConstants.peakWeeklyKm[dist] ?? 0;
      final cap = AdmissibilityConstants.maxKmPerSession[level] ?? 32;
      if (peak > 0 && freq > 0) {
        final projected = peak / freq;
        if (projected > cap) {
          final minFreqByVolume = (peak / cap).ceil();
          issues.add(SessionVolumeTooHigh(
            capKmPerSession: cap,
            projectedKmPerSession: projected,
            minFreqRequired: minFreqByVolume,
            level: level,
          ));
        }
      }
    }
  }

  // 1.5 Window restriction por (subnível × distância). Estática
  //     (nunca/esporadico + 10K → só safe) OU dinâmica (intermediario +
  //     21K + freq=3 → só safe). Pula se bypass.
  if (!isImprovePaceBypassed && s.windowMode != null && freq > 0) {
    final allowed = AdmissibilityConstants.getAllowedWindows(
      level, dist, freq,
      levelHint: s.levelHint,
    );
    if (allowed != null && !allowed.contains(s.windowMode)) {
      issues.add(WindowNotAllowedForProfile(
        distanceKm: dist,
        chosenWindow: s.windowMode!,
        allowedWindows: allowed,
      ));
    }
  }

  // 2. Volume ramp (precisa de weeksCount; pula se não escolheu ainda)
  final weeks = s.weeksCount;
  if (weeks != null && weeks > 0) {
    final requiredPeak = AdmissibilityConstants.peakWeeklyKm[dist] ?? 0;
    if (requiredPeak > 0) {
      final base = (s.currentWeeklyKm != null && s.currentWeeklyKm! > 0)
          ? (s.currentWeeklyKm! > AdmissibilityConstants.rampBaseFloorKm
              ? s.currentWeeklyKm!
              : AdmissibilityConstants.rampBaseFloorKm.toDouble())
          : AdmissibilityConstants.rampBaseFloorKm.toDouble();
      final ramped = base * _pow(AdmissibilityConstants.weeklyRampRate, weeks);
      if (ramped < requiredPeak) {
        issues.add(VolumeRampInsufficient(
          requiredPeakKm: requiredPeak,
          rampedKm: ramped,
          distanceKm: dist,
          weeksCount: weeks,
          redirectTo: AdmissibilityConstants.redirectTarget[dist],
        ));
      }
    }
  }

  // 3. Age (precisa de windowMode escolhido)
  final age = _computeAge(s.birthDate);
  if (age != null && s.windowMode != null) {
    final mode = s.windowMode!;
    String? recommended;
    if (age >= AdmissibilityConstants.forceSafeMarathonAge && dist == 42 && mode != 'safe') {
      recommended = 'safe';
    } else if (age >= AdmissibilityConstants.forceFeasibleHalfAge && dist == 21 && mode == 'aggressive') {
      recommended = 'feasible';
    } else if (age >= AdmissibilityConstants.blockAggressiveAge && dist == 42 && mode == 'aggressive') {
      recommended = 'feasible';
    }
    if (recommended != null) {
      issues.add(AgeRestriction(age: age, distanceKm: dist, recommendedMinWindow: recommended));
    }
  }

  // 4. Medical
  final med = s.medicalConditions.where((c) => c.trim().isNotEmpty).toList();
  if (med.isNotEmpty && s.windowMode != null && s.windowMode != 'safe') {
    if (med.length >= 3) {
      issues.add(MedicalRestriction(matchedConditions: med, reason: 'multiple_conditions'));
    } else if (dist >= 21) {
      final matched = <String>[];
      for (final c in med) {
        final norm = _normalize(c);
        for (final kw in AdmissibilityConstants.seriousMedicalKeywords) {
          if (norm.contains(kw)) {
            matched.add(c);
            break;
          }
        }
      }
      if (matched.isNotEmpty) {
        issues.add(MedicalRestriction(matchedConditions: matched, reason: 'serious_condition'));
      }
    }
  }

  // 5. Pace target
  if (s.raceMode == 'improve_pace' &&
      s.targetPaceMinKm != null &&
      s.currentPaceMinKm != null &&
      weeks != null && weeks > 0) {
    final current = _parsePaceSec(s.currentPaceMinKm!);
    final target = _parsePaceSec(s.targetPaceMinKm!);
    if (current != null && target != null && target < current) {
      final baseCeiling = AdmissibilityConstants.paceImprovementCeilingPct[level] ?? 5.0;
      final scale = (weeks / 12.0).clamp(0.5, 1.5);
      final maxPct = baseCeiling * scale;
      final requestedPct = ((current - target) / current) * 100;
      if (requestedPct > maxPct) {
        final suggestedSec = (current * (1 - maxPct / 100)).round();
        issues.add(PaceTargetTooAmbitious(
          maxImprovementPct: maxPct,
          suggestedTargetPace: _formatPace(suggestedSec),
        ));
      }
    }
  }

  if (issues.isEmpty) return AdmissibilityResult.ok_;

  // Monta sugestões na ordem da decision table (issue principal = primeira).
  final suggestions = _buildSuggestions(s, issues);
  return AdmissibilityResult(ok: false, issues: issues, suggestions: suggestions);
}

List<AdmissibilitySuggestion> _buildSuggestions(
  AdmissibilityState s,
  List<AdmissibilityIssue> issues,
) {
  final out = <AdmissibilitySuggestion>[];
  final primary = issues.first;
  final dist = s.raceDistanceKm!;

  if (primary is FrequencyTooLow) {
    out.add(IncreaseFrequency(primary.minRequired));
    final sub = AdmissibilityConstants.redirectTarget[dist];
    if (sub != null) out.add(SwitchDistance(sub));
  } else if (primary is LevelBlockedForDistance) {
    final sub = AdmissibilityConstants.redirectTarget[dist];
    if (sub != null) out.add(SwitchDistance(sub));
  } else if (primary is WindowNotAllowedForProfile) {
    // Sugere a primeira janela permitida (geralmente safe).
    final target = primary.allowedWindows.first;
    final row = AdmissibilityConstants.raceWindows[dist]?[s.level];
    if (row != null) {
      final weeks = target == 'safe'
          ? row.safe
          : (target == 'feasible' ? (row.feasible ?? row.safe) : (row.aggressive ?? row.feasible ?? row.safe));
      out.add(SwitchToSafeWindow(weeks));
    }
    final sub = AdmissibilityConstants.redirectTarget[dist];
    if (sub != null) out.add(SwitchDistance(sub));
  } else if (primary is SessionVolumeTooHigh) {
    out.add(IncreaseFrequency(primary.minFreqRequired));
    final sub = AdmissibilityConstants.redirectTarget[dist];
    if (sub != null) out.add(SwitchDistance(sub));
  } else if (primary is VolumeRampInsufficient) {
    final row = AdmissibilityConstants.raceWindows[dist]?[s.level];
    if (row != null && s.windowMode != 'safe') {
      out.add(SwitchToSafeWindow(row.safe));
    }
    if (primary.redirectTo != null) out.add(SwitchDistance(primary.redirectTo!));
  } else if (primary is AgeRestriction) {
    final row = AdmissibilityConstants.raceWindows[dist]?[s.level];
    if (row != null) {
      final weeks = primary.recommendedMinWindow == 'safe' ? row.safe : (row.feasible ?? row.safe);
      out.add(SwitchToSafeWindow(weeks));
    }
    final sub = AdmissibilityConstants.redirectTarget[dist];
    if (sub != null) out.add(SwitchDistance(sub));
  } else if (primary is MedicalRestriction) {
    final row = AdmissibilityConstants.raceWindows[dist]?[s.level];
    if (row != null) out.add(SwitchToSafeWindow(row.safe));
    final sub = AdmissibilityConstants.redirectTarget[dist];
    if (sub != null) out.add(SwitchDistance(sub));
  } else if (primary is PaceTargetTooAmbitious) {
    out.add(RelaxPaceTarget(primary.suggestedTargetPace));
    out.add(SwitchToCompleteMode());
  }

  // FLOW sempre como última opção (per decisão do user).
  out.add(SwitchToFlow());
  return out;
}

double _pow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}
