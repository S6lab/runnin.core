/// Espelho do PlanCheckpoint do server. Status:
///   scheduled    — criado, sem atividade
///   in_progress  — user abriu e/ou submeteu inputs
///   completed    — apply rodou (resultRevisionId aponta pra revision)
///   skipped      — passou da data sem apply
class PlanCheckpoint {
  final String id;
  final String planId;
  final int weekNumber;
  final String scheduledDate; // ISO YYYY-MM-DD
  final String status;
  final List<CheckpointInput> userInputs;
  final String? autoAnalysis;
  final String? resultRevisionId;
  final String? openedAt;
  final String? completedAt;
  final String createdAt;

  const PlanCheckpoint({
    required this.id,
    required this.planId,
    required this.weekNumber,
    required this.scheduledDate,
    required this.status,
    this.userInputs = const [],
    this.autoAnalysis,
    this.resultRevisionId,
    this.openedAt,
    this.completedAt,
    required this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get canApply => status == 'scheduled' || status == 'in_progress';

  factory PlanCheckpoint.fromJson(Map<String, dynamic> j) => PlanCheckpoint(
        id: j['id'] as String,
        planId: j['planId'] as String,
        weekNumber: j['weekNumber'] as int,
        scheduledDate: j['scheduledDate'] as String,
        status: j['status'] as String,
        userInputs: ((j['userInputs'] as List?) ?? [])
            .map((e) => CheckpointInput.fromJson(e as Map<String, dynamic>))
            .toList(),
        autoAnalysis: j['autoAnalysis'] as String?,
        resultRevisionId: j['resultRevisionId'] as String?,
        openedAt: j['openedAt'] as String?,
        completedAt: j['completedAt'] as String?,
        createdAt: j['createdAt'] as String,
      );
}

/// Tipos pré-determinados (chips no app). Espelham CheckpointInputType
/// do server. `other` + `pain` exigem note no UI.
enum CheckpointInputKind {
  loadUp('load_up', 'Quero MAIS carga', 'Semana foi tranquila, posso subir'),
  loadDown('load_down', 'Quero MENOS carga', 'Tá pesado, preciso aliviar'),
  pain('pain', 'Dor específica', 'Conta onde dói'),
  scheduleConflict('schedule_conflict', 'Agenda apertada', 'Vou ter menos dias livres'),
  lowEnergy('low_energy', 'Sem energia', 'Cansaço acumulado'),
  sleepBad('sleep_bad', 'Dormindo mal', 'Sono ruim afetando treino'),
  greatWeek('great_week', 'Semana excelente', 'Tô voando, manda mais'),
  other('other', 'Outro', 'Conta o que tá pegando');

  final String wire;
  final String label;
  final String hint;
  const CheckpointInputKind(this.wire, this.label, this.hint);

  static CheckpointInputKind fromWire(String wire) =>
      CheckpointInputKind.values.firstWhere(
        (k) => k.wire == wire,
        orElse: () => CheckpointInputKind.other,
      );

  bool get requiresNote => this == pain || this == other;
}

class CheckpointInput {
  final CheckpointInputKind kind;
  final String? note;

  const CheckpointInput({required this.kind, this.note});

  factory CheckpointInput.fromJson(Map<String, dynamic> j) => CheckpointInput(
        kind: CheckpointInputKind.fromWire(j['type'] as String),
        note: j['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'type': kind.wire,
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      };
}
