import 'dart:math';

/// Snapshot de métricas do RunBloc no momento de um turno do coach. Usado
/// pra anexar contexto numérico no log e pra compor o preamble da próxima
/// sessão Live em uma rotação.
class RunMetricsSnapshot {
  const RunMetricsSnapshot({
    this.distanceKm,
    this.elapsedS,
    this.avgPaceMinKm,
    this.currentPaceMinKm,
    this.avgBpm,
    this.currentPhase,
  });

  final double? distanceKm;
  final int? elapsedS;
  final double? avgPaceMinKm;
  final double? currentPaceMinKm;
  final int? avgBpm;
  final String? currentPhase;

  String? get paceAtTimeStr =>
      currentPaceMinKm != null ? _fmtPace(currentPaceMinKm!) : null;
}

class _CoachTurnEntry {
  _CoachTurnEntry({
    required this.text,
    required this.trigger,
    required this.metrics,
  });
  final String text;
  final String trigger;
  final RunMetricsSnapshot metrics;
}

/// Snapshot imutável do contexto, gerado on-demand pra alimentar o preamble
/// que reinjetamos na nova sessão Live em cada rotação.
class CoachContextSnapshot {
  CoachContextSnapshot({
    required this.generation,
    required this.distanceKm,
    required this.elapsedS,
    required this.avgPaceMinKm,
    required this.currentPaceMinKm,
    required this.avgBpm,
    required this.currentPhase,
    required this.lastCoachUtterances,
    required this.lastTriggers,
  });

  final int generation;
  final double? distanceKm;
  final int? elapsedS;
  final double? avgPaceMinKm;
  final double? currentPaceMinKm;
  final int? avgBpm;
  final String? currentPhase;
  final List<String> lastCoachUtterances; // últimas 3
  final List<String> lastTriggers;        // últimos 5

  /// Preamble de até 800 chars injetado como primeiro sendText logo após o
  /// setupComplete da nova sessão. Cap rígido pra evitar reincidência do
  /// próprio bug que estamos resolvendo (contexto inflando a sessão).
  String toPromptPreamble() {
    final pos = <String>[];
    if (distanceKm != null) pos.add('km ${distanceKm!.toStringAsFixed(1)}');
    if (elapsedS != null) pos.add(_fmtDur(elapsedS!));
    if (avgPaceMinKm != null && avgPaceMinKm! > 0) {
      pos.add('pace médio ${_fmtPace(avgPaceMinKm!)}/km');
    }
    if (currentPaceMinKm != null && currentPaceMinKm! > 0) {
      pos.add('pace atual ${_fmtPace(currentPaceMinKm!)}/km');
    }
    if (avgBpm != null) pos.add('FC $avgBpm');
    if (currentPhase != null && currentPhase!.isNotEmpty) {
      pos.add('fase: $currentPhase');
    }

    final lines = <String>[
      '[CONTEXTO ANTERIOR — você estava acompanhando esta corrida e a sessão foi reciclada por questão técnica]',
      if (pos.isNotEmpty) 'Posição: ${pos.join(' · ')}',
    ];
    if (lastCoachUtterances.isNotEmpty) {
      final quoted = lastCoachUtterances
          .map((u) => '"${_truncate(u, 80)}"')
          .join(', ');
      lines.add('Últimas falas suas: $quoted');
    }
    if (lastTriggers.isNotEmpty) {
      lines.add('Últimos eventos: ${lastTriggers.join(', ')}');
    }
    lines.add('Continue de onde parou — não repita a saudação, não pergunte de volta, apenas siga atendendo o atleta.');

    var out = lines.join('\n');
    if (out.length > 800) out = '${out.substring(0, 797)}...';
    return out;
  }
}

/// Vive durante a corrida inteira, independente da sessão Live. É o
/// source-of-truth do contexto pra reinjetar na rotação/reconexão.
///
/// Reside no app (zero RTT pra leitura). Persistência server-side via
/// beacon /coach/live-turn é feita por um datasource separado em
/// fire-and-forget — esse manager NÃO conhece o server.
class CoachContextManager {
  static const int _maxUtterances = 3;
  static const int _maxTriggers = 5;
  static const int _maxUtteranceLen = 200;

  String? _runId;
  int _generation = 0;
  final List<_CoachTurnEntry> _coachTurns = <_CoachTurnEntry>[];
  final List<String> _triggers = <String>[];
  RunMetricsSnapshot? _lastMetrics;

  bool get isInitialized => _runId != null;
  int get generation => _generation;
  String? get runId => _runId;
  int get coachTurnsCount => _coachTurns.length;

  void init(String runId) {
    _runId = runId;
    _generation = 0;
    _coachTurns.clear();
    _triggers.clear();
    _lastMetrics = null;
  }

  /// Incrementa a geração — chamado pelo LiveRunCoachSession após uma rotação
  /// bem-sucedida (nova sessão Live aberta com preamble injetado).
  void bumpGeneration() {
    _generation += 1;
  }

  void recordCoachTurn({
    required String text,
    required String trigger,
    required RunMetricsSnapshot metrics,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _coachTurns.add(_CoachTurnEntry(
      text: clean.length > _maxUtteranceLen
          ? clean.substring(0, _maxUtteranceLen)
          : clean,
      trigger: trigger,
      metrics: metrics,
    ));
    while (_coachTurns.length > _maxUtterances) {
      _coachTurns.removeAt(0);
    }
    _pushTrigger(trigger);
    _lastMetrics = metrics;
  }

  void recordUserPushToTalk({String? transcript}) {
    _pushTrigger('push_to_talk');
  }

  void recordEvent(String trigger, {RunMetricsSnapshot? metrics}) {
    _pushTrigger(trigger);
    if (metrics != null) _lastMetrics = metrics;
  }

  CoachContextSnapshot snapshot() {
    return CoachContextSnapshot(
      generation: _generation,
      distanceKm: _lastMetrics?.distanceKm,
      elapsedS: _lastMetrics?.elapsedS,
      avgPaceMinKm: _lastMetrics?.avgPaceMinKm,
      currentPaceMinKm: _lastMetrics?.currentPaceMinKm,
      avgBpm: _lastMetrics?.avgBpm,
      currentPhase: _lastMetrics?.currentPhase,
      lastCoachUtterances: _coachTurns.map((e) => e.text).toList(growable: false),
      lastTriggers: List<String>.unmodifiable(_triggers),
    );
  }

  void dispose() {
    _runId = null;
    _generation = 0;
    _coachTurns.clear();
    _triggers.clear();
    _lastMetrics = null;
  }

  void _pushTrigger(String trigger) {
    final t = trigger.trim();
    if (t.isEmpty) return;
    _triggers.add(t);
    while (_triggers.length > _maxTriggers) {
      _triggers.removeAt(0);
    }
  }
}

String _fmtPace(double p) {
  final m = p.floor();
  final s = ((p - m) * 60).round();
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _fmtDur(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m}min ${s}s';
}

String _truncate(String s, int max) {
  if (s.length <= max) return s;
  final cut = min(max - 1, s.length - 1);
  return '${s.substring(0, cut)}…';
}
