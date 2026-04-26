class GpsPoint {
  final double lat;
  final double lng;
  final int ts;
  final double accuracy;
  final double? pace;
  final int? bpm;

  const GpsPoint({
    required this.lat,
    required this.lng,
    required this.ts,
    required this.accuracy,
    this.pace,
    this.bpm,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat, 'lng': lng, 'ts': ts,
    'accuracy': accuracy,
    if (pace != null) 'pace': pace,
    if (bpm != null) 'bpm': bpm,
  };
}

class Run {
  final String id;
  final String status;
  final String type;
  final String? targetPace;
  final String? targetDistance;
  final double distanceM;
  final int durationS;
  final String? avgPace;
  final int? avgBpm;
  final int? xpEarned;
  final String? coachReportId;
  final String createdAt;

  const Run({
    required this.id,
    required this.status,
    required this.type,
    this.targetPace,
    this.targetDistance,
    required this.distanceM,
    required this.durationS,
    this.avgPace,
    this.avgBpm,
    this.xpEarned,
    this.coachReportId,
    required this.createdAt,
  });

  factory Run.fromJson(Map<String, dynamic> j) => Run(
    id: j['id'] as String,
    status: j['status'] as String,
    type: j['type'] as String,
    targetPace: j['targetPace'] as String?,
    targetDistance: j['targetDistance'] as String?,
    distanceM: (j['distanceM'] as num).toDouble(),
    durationS: j['durationS'] as int,
    avgPace: j['avgPace'] as String?,
    avgBpm: j['avgBpm'] as int?,
    xpEarned: j['xpEarned'] as int?,
    coachReportId: j['coachReportId'] as String?,
    createdAt: j['createdAt'] as String,
  );
}
