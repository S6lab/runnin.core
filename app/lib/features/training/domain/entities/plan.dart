class PlanSession {
  final String id;
  final int dayOfWeek; // 1=Seg … 7=Dom
  final String type;
  final double distanceKm;
  final String? targetPace;
  final String notes;
  final String warmupDuration;
  final String cooldownDuration;
  final List<String> instructions;
  final int? targetHeartRateMin;
  final int? targetHeartRateMax;
  final String? scheduledDate;

  const PlanSession({
    required this.id,
    required this.dayOfWeek,
    required this.type,
    required this.distanceKm,
    this.targetPace,
    required this.notes,
    this.warmupDuration = '10 min',
    this.cooldownDuration = '5 min',
    this.instructions = const [],
    this.targetHeartRateMin,
    this.targetHeartRateMax,
    this.scheduledDate,
  });

  factory PlanSession.fromJson(Map<String, dynamic> j) => PlanSession(
    id: j['id'] as String,
    dayOfWeek: j['dayOfWeek'] as int,
    type: j['type'] as String,
    distanceKm: (j['distanceKm'] as num).toDouble(),
    targetPace: j['targetPace'] as String?,
    notes: j['notes'] as String? ?? '',
    warmupDuration: j['warmupDuration'] as String? ?? '10 min',
    cooldownDuration: j['cooldownDuration'] as String? ?? '5 min',
    instructions: List<String>.from(j['instructions'] ?? []),
    targetHeartRateMin: j['targetHeartRateMin'] as int?,
    targetHeartRateMax: j['targetHeartRateMax'] as int?,
    scheduledDate: j['scheduledDate'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'dayOfWeek': dayOfWeek,
    'type': type,
    'distanceKm': distanceKm,
    if (targetPace != null) 'targetPace': targetPace,
    'notes': notes,
    'warmupDuration': warmupDuration,
    'cooldownDuration': cooldownDuration,
    'instructions': instructions,
    if (targetHeartRateMin != null) 'targetHeartRateMin': targetHeartRateMin,
    if (targetHeartRateMax != null) 'targetHeartRateMax': targetHeartRateMax,
    if (scheduledDate != null) 'scheduledDate': scheduledDate,
  };
}

class PlanWeek {
  final int weekNumber;
  final List<PlanSession> sessions;
  final String? weekType; // 'load' or 'recovery' for 3:1 mesocycle

  const PlanWeek({
    required this.weekNumber,
    required this.sessions,
    this.weekType,
  });

  factory PlanWeek.fromJson(Map<String, dynamic> j) => PlanWeek(
    weekNumber: j['weekNumber'] as int,
    sessions: (j['sessions'] as List)
        .map((s) => PlanSession.fromJson(s as Map<String, dynamic>))
        .toList(),
    weekType: j['weekType'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'weekNumber': weekNumber,
    'sessions': sessions.map((s) => s.toJson()).toList(),
    if (weekType != null) 'weekType': weekType,
  };

  bool get isRecoveryWeek => weekType == 'recovery';
}

class HeartRateZone {
  final int min;
  final int max;

  const HeartRateZone({required this.min, required this.max});

  factory HeartRateZone.fromJson(Map<String, dynamic> j) => HeartRateZone(
    min: j['min'] as int,
    max: j['max'] as int,
  );

  Map<String, dynamic> toJson() => {
    'min': min,
    'max': max,
  };
}

class HeartRateZones {
  final HeartRateZone zone1;
  final HeartRateZone zone2;
  final HeartRateZone zone3;
  final HeartRateZone zone4;
  final HeartRateZone zone5;
  final int maxHeartRate;

  const HeartRateZones({
    required this.zone1,
    required this.zone2,
    required this.zone3,
    required this.zone4,
    required this.zone5,
    required this.maxHeartRate,
  });

  factory HeartRateZones.fromJson(Map<String, dynamic> j) => HeartRateZones(
    zone1: HeartRateZone.fromJson(j['zone1'] as Map<String, dynamic>),
    zone2: HeartRateZone.fromJson(j['zone2'] as Map<String, dynamic>),
    zone3: HeartRateZone.fromJson(j['zone3'] as Map<String, dynamic>),
    zone4: HeartRateZone.fromJson(j['zone4'] as Map<String, dynamic>),
    zone5: HeartRateZone.fromJson(j['zone5'] as Map<String, dynamic>),
    maxHeartRate: j['maxHeartRate'] as int,
  );

  Map<String, dynamic> toJson() => {
    'zone1': zone1.toJson(),
    'zone2': zone2.toJson(),
    'zone3': zone3.toJson(),
    'zone4': zone4.toJson(),
    'zone5': zone5.toJson(),
    'maxHeartRate': maxHeartRate,
  };
}

class GenerationProgress {
  final int currentStage;
  final int totalStages;
  final String stageName;
  final String stageDescription;

  const GenerationProgress({
    required this.currentStage,
    required this.totalStages,
    required this.stageName,
    required this.stageDescription,
  });

  factory GenerationProgress.fromJson(Map<String, dynamic> j) =>
      GenerationProgress(
        currentStage: j['currentStage'] as int,
        totalStages: j['totalStages'] as int,
        stageName: j['stageName'] as String,
        stageDescription: j['stageDescription'] as String,
      );

  Map<String, dynamic> toJson() => {
    'currentStage': currentStage,
    'totalStages': totalStages,
    'stageName': stageName,
    'stageDescription': stageDescription,
  };
}

class Plan {
  final String id;
  final String goal;
  final String level;
  final int weeksCount;
  final String status;
  final List<PlanWeek> weeks;
  final String createdAt;
  final HeartRateZones? heartRateZones;
  final GenerationProgress? generationProgress;

  const Plan({
    required this.id,
    required this.goal,
    required this.level,
    required this.weeksCount,
    required this.status,
    required this.weeks,
    required this.createdAt,
    this.heartRateZones,
    this.generationProgress,
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
        heartRateZones: j['heartRateZones'] != null
            ? HeartRateZones.fromJson(
                j['heartRateZones'] as Map<String, dynamic>)
            : null,
        generationProgress: j['generationProgress'] != null
            ? GenerationProgress.fromJson(
                j['generationProgress'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'goal': goal,
    'level': level,
    'weeksCount': weeksCount,
    'status': status,
    'weeks': weeks.map((w) => w.toJson()).toList(),
    'createdAt': createdAt,
    if (heartRateZones != null) 'heartRateZones': heartRateZones!.toJson(),
    if (generationProgress != null) 'generationProgress': generationProgress!.toJson(),
  };

  bool get isReady => status == 'ready';
  bool get isGenerating => status == 'generating';
}
