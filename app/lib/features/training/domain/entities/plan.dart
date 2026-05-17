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

class PlanRevision {
  final int weekNumber;
  final String revisedAt;
  final String trigger;
  final String summary;
  final String? details;

  const PlanRevision({
    required this.weekNumber,
    required this.revisedAt,
    required this.trigger,
    required this.summary,
    this.details,
  });

  factory PlanRevision.fromJson(Map<String, dynamic> j) => PlanRevision(
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
  /// Markdown longo escrito pelo coach AI (gerado em background no server).
  /// Pode estar null se ainda não foi gerado ou se a chamada LLM falhou.
  final String? coachRationale;
  /// Texto curto (3-4 frases) sobre estratégia do mesociclo todo.
  final String? mesocycleNarrative;
  final List<PlanRevision> revisions;

  const Plan({
    required this.id,
    required this.goal,
    required this.level,
    required this.weeksCount,
    required this.status,
    required this.weeks,
    required this.createdAt,
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
        coachRationale: j['coachRationale'] as String?,
        mesocycleNarrative: j['mesocycleNarrative'] as String?,
        revisions: ((j['revisions'] as List?) ?? [])
            .map((r) => PlanRevision.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  bool get isReady => status == 'ready';
  bool get isGenerating => status == 'generating';
}
