class PlanRevision {
  final String id;
  final String planId;
  final String type;
  final String? subOption;
  final String? freeText;
  final String coachExplanation;
  final String status;
  final int weekIndex;
  final String createdAt;

  const PlanRevision({
    required this.id,
    required this.planId,
    required this.type,
    this.subOption,
    this.freeText,
    required this.coachExplanation,
    required this.status,
    required this.weekIndex,
    required this.createdAt,
  });

  factory PlanRevision.fromJson(Map<String, dynamic> j) => PlanRevision(
    id: j['id'] as String,
    planId: j['planId'] as String,
    type: j['type'] as String,
    subOption: j['subOption'] as String?,
    freeText: j['freeText'] as String?,
    coachExplanation: j['coachExplanation'] as String,
    status: j['status'] as String,
    weekIndex: j['weekIndex'] as int,
    createdAt: j['createdAt'] as String,
  );

  bool get isApplied => status == 'applied';
}
