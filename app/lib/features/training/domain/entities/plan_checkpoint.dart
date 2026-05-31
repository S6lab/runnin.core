/// Tipos pré-determinados (chips no app). Espelham CheckpointInputType
/// do server. `other` + `pain` exigem note no UI.
///
/// Apesar do nome "Checkpoint", esses chips agora alimentam o feedback
/// PÓS-CORRIDA (ReportPage → PATCH /runs/:id/feedback). O cron de
/// domingo agrega o feedback das runs da semana pra propor revisão do
/// plano — o fluxo de checkpoint solto foi removido.
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
