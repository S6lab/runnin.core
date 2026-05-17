/// Segmento de execução de uma sessão (km-a-km com instrução do coach).
/// Renderizado no DayDetailPage como timeline ordenada.
class PlanSegment {
  final double kmStart;
  final double kmEnd;
  final String phase; // warmup | main | interval | recovery | cooldown
  final String? targetPace;
  final double? durationMin;
  final String instruction;

  const PlanSegment({
    required this.kmStart,
    required this.kmEnd,
    required this.phase,
    this.targetPace,
    this.durationMin,
    required this.instruction,
  });

  factory PlanSegment.fromJson(Map<String, dynamic> j) => PlanSegment(
        kmStart: (j['kmStart'] as num).toDouble(),
        kmEnd: (j['kmEnd'] as num).toDouble(),
        phase: j['phase'] as String,
        targetPace: j['targetPace'] as String?,
        durationMin: (j['durationMin'] as num?)?.toDouble(),
        instruction: j['instruction'] as String,
      );
}

class PlanSession {
  final String id;
  final int dayOfWeek; // 1=Seg … 7=Dom
  final String type;
  final double distanceKm;
  final String? targetPace;
  final double? durationMin;
  final double? hydrationLiters;
  final String? nutritionPre;
  final String? nutritionPost;
  /// Roteiro detalhado km-a-km da sessão. Aparece SOMENTE no DayDetail
  /// (clicar no dia da semana em TREINO/Plano). Plano completo só mostra
  /// agregado (distância/pace/tempo) pra não poluir.
  final List<PlanSegment> executionSegments;
  final String notes;

  const PlanSession({
    required this.id,
    required this.dayOfWeek,
    required this.type,
    required this.distanceKm,
    this.targetPace,
    this.durationMin,
    this.hydrationLiters,
    this.nutritionPre,
    this.nutritionPost,
    this.executionSegments = const [],
    required this.notes,
  });

  factory PlanSession.fromJson(Map<String, dynamic> j) => PlanSession(
    id: j['id'] as String,
    dayOfWeek: j['dayOfWeek'] as int,
    type: j['type'] as String,
    distanceKm: (j['distanceKm'] as num).toDouble(),
    targetPace: j['targetPace'] as String?,
    durationMin: (j['durationMin'] as num?)?.toDouble(),
    hydrationLiters: (j['hydrationLiters'] as num?)?.toDouble(),
    nutritionPre: j['nutritionPre'] as String?,
    nutritionPost: j['nutritionPost'] as String?,
    executionSegments: ((j['executionSegments'] as List?) ?? [])
        .map((e) => PlanSegment.fromJson(e as Map<String, dynamic>))
        .toList(),
    notes: j['notes'] as String? ?? '',
  );
}

class PlanRestDayTip {
  final int dayOfWeek;
  final double? hydrationLiters;
  final String? nutrition;
  final String? focus;

  const PlanRestDayTip({
    required this.dayOfWeek,
    this.hydrationLiters,
    this.nutrition,
    this.focus,
  });

  factory PlanRestDayTip.fromJson(Map<String, dynamic> j) => PlanRestDayTip(
        dayOfWeek: j['dayOfWeek'] as int,
        hydrationLiters: (j['hydrationLiters'] as num?)?.toDouble(),
        nutrition: j['nutrition'] as String?,
        focus: j['focus'] as String?,
      );
}

/// Snapshot de uma revisão semanal do plano (renomeado pra não colidir
/// com `PlanRevision` legada em [plan_revision.dart] que representa o
/// pedido manual de revisão).
class PlanRevisionLog {
  final int weekNumber;
  final String revisedAt;
  final String trigger;
  final String summary;
  final String? details;

  const PlanRevisionLog({
    required this.weekNumber,
    required this.revisedAt,
    required this.trigger,
    required this.summary,
    this.details,
  });

  factory PlanRevisionLog.fromJson(Map<String, dynamic> j) => PlanRevisionLog(
        weekNumber: j['weekNumber'] as int,
        revisedAt: j['revisedAt'] as String,
        trigger: j['trigger'] as String? ?? 'manual',
        summary: j['summary'] as String? ?? '',
        details: j['details'] as String?,
      );
}

class PlanWeek {
  final int weekNumber;
  final List<PlanSession> sessions;
  /// Texto curto (1-2 frases) gerado pela IA, personalizado para essa
  /// semana específica do user. Null se ainda não gerado.
  final String? narrative;
  final String? focus;
  final List<PlanRestDayTip> restDayTips;

  const PlanWeek({
    required this.weekNumber,
    required this.sessions,
    this.narrative,
    this.focus,
    this.restDayTips = const [],
  });

  factory PlanWeek.fromJson(Map<String, dynamic> j) => PlanWeek(
        weekNumber: j['weekNumber'] as int,
        sessions: (j['sessions'] as List)
            .map((s) => PlanSession.fromJson(s as Map<String, dynamic>))
            .toList(),
        narrative: j['narrative'] as String?,
        focus: j['focus'] as String?,
        restDayTips: ((j['restDayTips'] as List?) ?? [])
            .map((t) => PlanRestDayTip.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

class Plan {
  final String id;
  final String goal;
  final String level;
  final int weeksCount;
  final String status;
  final List<PlanWeek> weeks;
  final String createdAt;
  /// D0 escolhida pelo user no onboarding (ISO YYYY-MM-DD). Periodização
  /// (semana 1 dia 1, mesociclo end) é calculada a partir daqui.
  final String? startDate;
  /// Markdown longo escrito pelo coach AI (gerado em background no server).
  /// Pode estar null se ainda não foi gerado ou se a chamada LLM falhou.
  final String? coachRationale;
  /// Texto curto (3-4 frases) sobre estratégia do mesociclo todo.
  final String? mesocycleNarrative;
  final List<PlanRevisionLog> revisions;

  const Plan({
    required this.id,
    required this.goal,
    required this.level,
    required this.weeksCount,
    required this.status,
    required this.weeks,
    required this.createdAt,
    this.startDate,
    this.coachRationale,
    this.mesocycleNarrative,
    this.revisions = const [],
  });

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as String,
        goal: j['goal'] as String,
        level: j['level'] as String,
        weeksCount: j['weeksCount'] as int,
        status: j['status'] as String,
        weeks: ((j['weeks'] as List?) ?? [])
            .map((w) => PlanWeek.fromJson(w as Map<String, dynamic>))
            .toList(),
        createdAt: j['createdAt'] as String,
        startDate: j['startDate'] as String?,
        coachRationale: j['coachRationale'] as String?,
        mesocycleNarrative: j['mesocycleNarrative'] as String?,
        revisions: ((j['revisions'] as List?) ?? [])
            .map((r) => PlanRevisionLog.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  bool get isReady => status == 'ready';
  bool get isGenerating => status == 'generating';

  /// D0 efetiva: startDate (escolhida no onboarding) ou createdAt como
  /// fallback pra planos legados.
  DateTime get effectiveStartDate {
    final s = startDate;
    if (s != null && s.isNotEmpty) {
      final d = DateTime.tryParse(s);
      if (d != null) return d;
    }
    return DateTime.tryParse(createdAt) ?? DateTime.now();
  }

  /// Última data do mesociclo (inclusive). Útil pra mostrar
  /// "começa 18/05 → termina 12/07" no header do plan-detail.
  DateTime get mesocycleEndDate =>
      effectiveStartDate.add(Duration(days: weeksCount * 7 - 1));
}
