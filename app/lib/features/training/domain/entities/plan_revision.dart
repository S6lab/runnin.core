import 'package:runnin/features/training/domain/entities/plan.dart';

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
  /// Snapshot das semanas ANTES do ajuste (semanas futuras). Presente em
  /// propostas pendentes (cron de domingo).
  final List<PlanWeek> oldWeeksSnapshot;
  /// Snapshot PROPOSTO das semanas seguintes. Renderizado na tela de proposta.
  final List<PlanWeek> newWeeksSnapshot;

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
    this.oldWeeksSnapshot = const [],
    this.newWeeksSnapshot = const [],
  });

  factory PlanRevision.fromJson(Map<String, dynamic> j) => PlanRevision(
    id: j['id'] as String,
    planId: j['planId'] as String,
    type: j['type'] as String,
    subOption: j['subOption'] as String?,
    freeText: j['freeText'] as String?,
    coachExplanation: j['coachExplanation'] as String,
    status: j['status'] as String,
    weekIndex: (j['weekIndex'] as num).toInt(),
    createdAt: j['createdAt'] as String,
    oldWeeksSnapshot: ((j['oldWeeksSnapshot'] as List?) ?? [])
        .map((w) => PlanWeek.fromJson(w as Map<String, dynamic>))
        .toList(),
    newWeeksSnapshot: ((j['newWeeksSnapshot'] as List?) ?? [])
        .map((w) => PlanWeek.fromJson(w as Map<String, dynamic>))
        .toList(),
  );

  bool get isApplied => status == 'applied';
  bool get isPending => status == 'pending';
}
