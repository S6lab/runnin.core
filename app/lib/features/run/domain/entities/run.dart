import 'dart:math' as math;

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

/// Pace em segundos/km para cada km completado da corrida, calculado
/// caminhando pelos pontos GPS. Retorna lista vazia se não houver pelo
/// menos 2 pontos. Usado em widgets de share/relatório onde queremos
/// mostrar evolução de pace por km baseado em dado real.
List<double> computeKmSplitsSeconds(List<GpsPoint> points) {
  if (points.length < 2) return const [];
  final splits = <double>[];
  double cumDist = 0; // m
  int kmReached = 0;
  int kmStartTs = points.first.ts;
  double kmStartDist = 0;
  for (int i = 1; i < points.length; i++) {
    final p0 = points[i - 1];
    final p1 = points[i];
    cumDist += _haversineM(p0.lat, p0.lng, p1.lat, p1.lng);
    while (cumDist >= (kmReached + 1) * 1000) {
      final kmDistM = cumDist - kmStartDist;
      final kmTimeS = (p1.ts - kmStartTs) / 1000.0;
      if (kmDistM > 0 && kmTimeS > 0) {
        // pace seg/km = (kmTimeS / kmDistM) * 1000
        splits.add((kmTimeS / kmDistM) * 1000.0);
      }
      kmReached++;
      kmStartTs = p1.ts;
      kmStartDist = cumDist;
    }
  }
  return splits;
}

double _haversineM(double lat1, double lng1, double lat2, double lng2) {
  const earthR = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthR * math.asin(math.sqrt(a));
}

double _toRad(double deg) => deg * math.pi / 180.0;

class KmSplit {
  final int kmIndex;
  final int durationS;
  final String? avgPaceMinKm;
  final int? avgBpm;

  const KmSplit({
    required this.kmIndex,
    required this.durationS,
    this.avgPaceMinKm,
    this.avgBpm,
  });

  factory KmSplit.fromJson(Map<String, dynamic> j) => KmSplit(
        kmIndex: (j['kmIndex'] as num).toInt(),
        durationS: (j['durationS'] as num).toInt(),
        avgPaceMinKm: j['avgPaceMinKm'] as String?,
        avgBpm: (j['avgBpm'] as num?)?.toInt(),
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
  final int? maxBpm;
  /// Calorias estimadas (kcal). Calculado pelo server no complete-run
  /// via MET × peso × tempo. Null se server ainda não suportava no
  /// momento da corrida (campos retroativos viram null).
  final int? calories;
  final int? xpEarned;
  final String? coachReportId;
  final List<String>? newBadges;
  final String createdAt;
  final int? elapsedSeconds;
  final double? elevationGain;
  final String? deviceInfo;
  final String? planSessionId;
  final String? coachQuote;
  final List<KmSplit> splits;

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
    this.maxBpm,
    this.calories,
    this.xpEarned,
    this.coachReportId,
    this.newBadges,
    required this.createdAt,
    this.elapsedSeconds,
    this.elevationGain,
    this.deviceInfo,
    this.planSessionId,
    this.coachQuote,
    this.splits = const [],
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
    avgBpm: (j['avgBpm'] as num?)?.toInt(),
    maxBpm: (j['maxBpm'] as num?)?.toInt(),
    calories: (j['calories'] as num?)?.toInt(),
    xpEarned: (j['xpEarned'] as num?)?.toInt(),
    coachReportId: j['coachReportId'] as String?,
    newBadges: j['newBadges'] != null
        ? (j['newBadges'] as List).map((e) => e as String).toList()
        : null,
    createdAt: j['createdAt'] as String,
    elapsedSeconds: (j['elapsedSeconds'] as num?)?.toInt(),
    elevationGain: (j['elevationGain'] as num?)?.toDouble(),
    deviceInfo: j['deviceInfo'] as String?,
    planSessionId: j['planSessionId'] as String?,
    coachQuote: j['coachQuote'] as String?,
    splits: j['splits'] != null
        ? (j['splits'] as List)
            .map((e) => KmSplit.fromJson(e as Map<String, dynamic>))
            .toList()
        : const [],
  );
}
