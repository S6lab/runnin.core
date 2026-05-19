import 'dart:math' as math;

class GpsPoint {
  final double lat;
  final double lng;
  final int ts;
  final double accuracy;
  /// Altitude (m) reportada pelo device. Null quando o sensor não disponibiliza
  /// (ex: web sem barômetro). Usado pra somar elevação por km nos splits.
  final double? altitude;
  final double? pace;
  final int? bpm;

  const GpsPoint({
    required this.lat,
    required this.lng,
    required this.ts,
    required this.accuracy,
    this.altitude,
    this.pace,
    this.bpm,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat, 'lng': lng, 'ts': ts,
    'accuracy': accuracy,
    if (altitude != null) 'altitude': altitude,
    if (pace != null) 'pace': pace,
    if (bpm != null) 'bpm': bpm,
  };

  factory GpsPoint.fromJson(Map<String, dynamic> j) => GpsPoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        ts: (j['ts'] as num).toInt(),
        accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
        altitude: (j['altitude'] as num?)?.toDouble(),
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
  /// Calorias estimadas (kcal) do km. App não preenche — server calcula em
  /// CompleteRunUseCase via MET × peso × tempo do km e devolve no GET /runs/:id.
  final int? calories;
  /// Ganho de elevação (m) do km — soma de deltas positivos de altitude dos
  /// GPS points dentro do intervalo. Null quando o device não emite altitude.
  final double? elevationGain;

  const KmSplit({
    required this.kmIndex,
    required this.durationS,
    this.avgPaceMinKm,
    this.avgBpm,
    this.calories,
    this.elevationGain,
  });

  factory KmSplit.fromJson(Map<String, dynamic> j) => KmSplit(
        kmIndex: (j['kmIndex'] as num).toInt(),
        durationS: (j['durationS'] as num).toInt(),
        avgPaceMinKm: j['avgPaceMinKm'] as String?,
        avgBpm: (j['avgBpm'] as num?)?.toInt(),
        calories: (j['calories'] as num?)?.toInt(),
        elevationGain: (j['elevationGain'] as num?)?.toDouble(),
      );

  /// Payload pra enviar splits[] no PATCH /runs/:id/complete. NÃO inclui
  /// calorias — server calcula a partir do peso do perfil.
  Map<String, dynamic> toCompletePayload() => {
        'kmIndex': kmIndex,
        'durationS': durationS,
        'avgPaceMinKm': avgPaceMinKm ?? formattedPace,
        if (avgBpm != null) 'avgBpm': avgBpm,
        if (elevationGain != null) 'elevationGain': elevationGain,
      };

  /// Pace formatado mm:ss/km. Usa avgPaceMinKm se vier do backend, senão
  /// deriva de durationS (1km = durationS segundos → pace = durationS/60).
  String get formattedPace {
    if (avgPaceMinKm != null && avgPaceMinKm!.isNotEmpty) return avgPaceMinKm!;
    if (durationS <= 0) return '--:--';
    final m = durationS ~/ 60;
    final s = durationS % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Duração formatada mm:ss (mesma representação que pace pra splits de 1km).
  String get formattedDuration => formattedPace;

  /// Velocidade média em km/h. 1km / (durationS/3600).
  double get avgSpeedKmh {
    if (durationS <= 0) return 0;
    return 3600.0 / durationS;
  }

  /// Payload compacto pro evento coach.message do tipo km_analysis. Mantém
  /// só os campos que o LLM usa pra recomendar (kmIndex, durationS, pace).
  Map<String, dynamic> toCoachPayload() => {
        'kmIndex': kmIndex,
        'durationS': durationS,
        if (avgPaceMinKm != null) 'avgPaceMinKm': avgPaceMinKm,
        if (avgBpm != null) 'avgBpm': avgBpm,
      };
}

/// Constrói List<KmSplit> a partir de pontos GPS. Computa em uma única
/// passada: durationS, avgPaceMinKm, avgBpm (média dos points com BPM no
/// intervalo do km) e elevationGain (soma de deltas positivos de altitude).
/// Calorias ficam null — server preenche no complete.
List<KmSplit> computeKmSplits(List<GpsPoint> points) {
  if (points.length < 2) return const [];
  final splits = <KmSplit>[];
  double cumDist = 0;
  int kmReached = 0;
  int kmStartTs = points.first.ts;
  double kmStartDist = 0;
  int bpmSum = 0;
  int bpmCount = 0;
  double elevGain = 0;
  double? prevAlt = points.first.altitude;
  bool anyAlt = points.first.altitude != null;

  for (int i = 1; i < points.length; i++) {
    final p0 = points[i - 1];
    final p1 = points[i];
    cumDist += _haversineM(p0.lat, p0.lng, p1.lat, p1.lng);
    if (p1.bpm != null && p1.bpm! > 0) {
      bpmSum += p1.bpm!;
      bpmCount++;
    }
    if (p1.altitude != null) {
      anyAlt = true;
      if (prevAlt != null) {
        final delta = p1.altitude! - prevAlt;
        if (delta > 0) elevGain += delta;
      }
      prevAlt = p1.altitude;
    }
    while (cumDist >= (kmReached + 1) * 1000) {
      final kmDistM = cumDist - kmStartDist;
      final kmTimeS = (p1.ts - kmStartTs) / 1000.0;
      if (kmDistM > 0 && kmTimeS > 0) {
        final s = kmTimeS.round();
        final m = s ~/ 60;
        final sec = s % 60;
        splits.add(KmSplit(
          kmIndex: kmReached,
          durationS: s,
          avgPaceMinKm: '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
          avgBpm: bpmCount > 0 ? (bpmSum / bpmCount).round() : null,
          elevationGain: anyAlt ? double.parse(elevGain.toStringAsFixed(1)) : null,
        ));
      }
      kmReached++;
      kmStartTs = p1.ts;
      kmStartDist = cumDist;
      bpmSum = 0;
      bpmCount = 0;
      elevGain = 0;
    }
  }
  return splits;
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
