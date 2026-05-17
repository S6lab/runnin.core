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

  factory GpsPoint.fromJson(Map<String, dynamic> j) => GpsPoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        ts: (j['ts'] as num).toInt(),
        accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
        pace: (j['pace'] as num?)?.toDouble(),
        bpm: (j['bpm'] as num?)?.toInt(),
      );
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
  final List<String>? newBadges;
  final String createdAt;
  final int? elapsedSeconds;
  final double? elevationGain;
  final String? deviceInfo;
  final String? planSessionId;

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
    this.newBadges,
    required this.createdAt,
    this.elapsedSeconds,
    this.elevationGain,
    this.deviceInfo,
    this.planSessionId,
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
    newBadges: j['newBadges'] != null
        ? (j['newBadges'] as List).map((e) => e as String).toList()
        : null,
    createdAt: j['createdAt'] as String,
    elapsedSeconds: j['elapsedSeconds'] as int?,
    elevationGain: (j['elevationGain'] as num?)?.toDouble(),
    deviceInfo: j['deviceInfo'] as String?,
    planSessionId: j['planSessionId'] as String?,
  );
}
