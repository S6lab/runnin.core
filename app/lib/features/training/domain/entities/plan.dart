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
  /// ID da Run que executou essa sessão. Server seta em CompleteRun
  /// quando run.planSessionId == session.id. Null = sessão ainda
  /// não foi feita.
  final String? executedRunId;
  final String? executedAt;
  /// Marca a SESSÃO-META do plano RACE (última sessão da última semana).
  /// Server seta via `markTargetSession` pós-LLM — distância = meta exata,
  /// isenta do cap MAX_KM_PER_SESSION. UI renderiza badge "SESSÃO ALVO".
  final bool isTarget;

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
    this.executedRunId,
    this.executedAt,
    this.isTarget = false,
  });

  bool get isExecuted => executedRunId != null && executedRunId!.isNotEmpty;

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
    executedRunId: j['executedRunId'] as String?,
    executedAt: j['executedAt'] as String?,
    isTarget: j['isTarget'] as bool? ?? false,
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
  /// Nível de detalhe (geração two-tier): 'full' = sessões completas com
  /// roteiro/nutrição; 'skeleton' = só tipo/distância/pace, detalhe liberado
  /// no checkpoint. Ausente = 'full' (planos legados).
  final String? detailLevel;
  /// Nome didático do bloco/fase (ex: "BASE · Adaptação").
  final String? blockName;
  /// Objetivo da semana em 1 frase.
  final String? objective;
  /// Carga projetada da semana (km).
  final double? projectedLoadKm;
  /// Objetivos a atingir na semana (bullets).
  final List<String> targets;
  final List<PlanRestDayTip> restDayTips;

  const PlanWeek({
    required this.weekNumber,
    required this.sessions,
    this.narrative,
    this.focus,
    this.detailLevel,
    this.blockName,
    this.objective,
    this.projectedLoadKm,
    this.targets = const [],
    this.restDayTips = const [],
  });

  /// Semana esqueleto: só volume/pace, sem detalhe rico (liberado no
  /// checkpoint da semana anterior). Default false p/ planos legados.
  bool get isSkeleton => detailLevel == 'skeleton';

  factory PlanWeek.fromJson(Map<String, dynamic> j) => PlanWeek(
        weekNumber: j['weekNumber'] as int,
        sessions: (j['sessions'] as List)
            .map((s) => PlanSession.fromJson(s as Map<String, dynamic>))
            .toList(),
        narrative: j['narrative'] as String?,
        focus: j['focus'] as String?,
        detailLevel: j['detailLevel'] as String?,
        blockName: j['blockName'] as String?,
        objective: j['objective'] as String?,
        projectedLoadKm: (j['projectedLoadKm'] as num?)?.toDouble(),
        targets: ((j['targets'] as List?) ?? [])
            .map((t) => t as String)
            .toList(),
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
  /// Avaliação honesta do objetivo: o coach diz se a meta é alcançável neste
  /// mesociclo ou se o plano é só a fundação. Renderizado em destaque.
  final String? goalAssessment;
  final List<PlanRevisionLog> revisions;
  /// Prazo INICIAL pra atingir o objetivo (ISO YYYY-MM-DD), gravado na
  /// criação do plano. Imutável — checkpoints podem ajustar weeksCount, mas
  /// este campo serve de baseline pro relatório final ("prazo inicial × real").
  final String? initialDeadlineAt;
  /// Data em que o plano foi marcado como completed (detecção lazy no
  /// server quando mesocycleEndDate < hoje). Null = ainda em curso.
  final String? completedAt;

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
    this.goalAssessment,
    this.revisions = const [],
    this.initialDeadlineAt,
    this.completedAt,
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
        goalAssessment: j['goalAssessment'] as String?,
        revisions: ((j['revisions'] as List?) ?? [])
            .map((r) => PlanRevisionLog.fromJson(r as Map<String, dynamic>))
            .toList(),
        initialDeadlineAt: j['initialDeadlineAt'] as String?,
        completedAt: j['completedAt'] as String?,
      );

  bool get isReady => status == 'ready';
  bool get isGenerating => status == 'generating';
  bool get isCompleted => status == 'completed';

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
