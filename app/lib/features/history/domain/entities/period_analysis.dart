class PeriodAnalysisStatus {
  static const pending = 'pending';
  static const ready = 'ready';
}

class PeriodAnalysis {
  final String userId;
  final List<PeriodAnalysisRun> runs;
  final String summary;
  final String status;
  final String generatedAt;

  const PeriodAnalysis({
    required this.userId,
    required this.runs,
    required this.summary,
    required this.status,
    required this.generatedAt,
  });

  factory PeriodAnalysis.fromJson(Map<String, dynamic> json) {
    return PeriodAnalysis(
      userId: json['userId'] as String,
      runs: (json['runs'] as List<dynamic>? ?? [])
          .map((e) => PeriodAnalysisRun.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String,
      status: json['status'] as String,
      generatedAt: json['generatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'runs': runs.map((e) => e.toJson()).toList(),
      'summary': summary,
      'status': status,
      'generatedAt': generatedAt,
    };
  }
}

class PeriodAnalysisRun {
  final String id;
  final double distanceM;
  final int durationS;
  final String? avgPace;
  final int? avgBpm;
  final int? maxBpm;
  final String type;
  final String date;

  const PeriodAnalysisRun({
    required this.id,
    required this.distanceM,
    required this.durationS,
    this.avgPace,
    this.avgBpm,
    this.maxBpm,
    required this.type,
    required this.date,
  });

  factory PeriodAnalysisRun.fromJson(Map<String, dynamic> json) {
    return PeriodAnalysisRun(
      id: json['id'] as String,
      distanceM: (json['distanceM'] as num).toDouble(),
      durationS: json['durationS'] as int,
      avgPace: json['avgPace'] as String?,
      avgBpm: json['avgBpm'] as int?,
      maxBpm: json['maxBpm'] as int?,
      type: json['type'] as String,
      date: json['date'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'distanceM': distanceM,
      'durationS': durationS,
      if (avgPace != null) 'avgPace': avgPace,
      if (avgBpm != null) 'avgBpm': avgBpm,
      if (maxBpm != null) 'maxBpm': maxBpm,
      'type': type,
      'date': date,
    };
  }
}
