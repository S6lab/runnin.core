class PlanSession {
  final String id;
  final int dayOfWeek; // 1=Seg … 7=Dom
  final String type;
  final double distanceKm;
  final String? targetPace;
  final String notes;

  const PlanSession({
    required this.id,
    required this.dayOfWeek,
    required this.type,
    required this.distanceKm,
    this.targetPace,
    required this.notes,
  });

  factory PlanSession.fromJson(Map<String, dynamic> j) => PlanSession(
    id: j['id'] as String,
    dayOfWeek: j['dayOfWeek'] as int,
    type: j['type'] as String,
    distanceKm: (j['distanceKm'] as num).toDouble(),
    targetPace: j['targetPace'] as String?,
    notes: j['notes'] as String? ?? '',
  );
}

class PlanWeek {
  final int weekNumber;
  final List<PlanSession> sessions;

  const PlanWeek({required this.weekNumber, required this.sessions});

  factory PlanWeek.fromJson(Map<String, dynamic> j) => PlanWeek(
    weekNumber: j['weekNumber'] as int,
    sessions: (j['sessions'] as List)
        .map((s) => PlanSession.fromJson(s as Map<String, dynamic>))
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

  const Plan({
    required this.id,
    required this.goal,
    required this.level,
    required this.weeksCount,
    required this.status,
    required this.weeks,
    required this.createdAt,
    this.coachRationale,
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
  );

  bool get isReady => status == 'ready';
  bool get isGenerating => status == 'generating';
}
