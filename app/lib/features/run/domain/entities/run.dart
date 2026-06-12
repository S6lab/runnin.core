import 'dart:math' as math;
import 'package:runnin/features/badges/domain/entities/badge.dart' as badge_e;
import 'package:runnin/features/training/domain/entities/plan_checkpoint.dart';

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
  /// TF 75 Fase 10: BPM máximo dentro do split (pico). Útil pra detectar
  /// trecho de esforço (subida, sprint) e relatar no review pós-run.
  final int? maxBpm;
  /// Calorias estimadas (kcal) do km. App não preenche — server calcula em
  /// CompleteRunUseCase via MET × peso × tempo do km e devolve no GET /runs/:id.
  final int? calories;
  /// Ganho de elevação (m) do km — deltas positivos de altitude com
  /// histerese de 3m (só conta quando o acumulado desde a última referência
  /// passa do threshold; ruído GPS de ±5-15m inflava o número antes).
  /// Null quando o device não emite altitude.
  final double? elevationGain;
  /// Perda de elevação (m) do km — espelho do ganho (mesma histerese).
  /// Null em runs antigas / sem altitude.
  final double? elevationLoss;
  /// Distância real do split em metros. Para splits completos fica null
  /// (server assume 1000m); para parciais preenche com a leftover (ex: 40m
  /// quando a corrida termina em 3.04km). Necessário pro server calcular
  /// calorias proporcionais.
  final double? distanceM;
  /// True quando o split é parcial — não fechou os 1000m. Renderizado com
  /// marca visual ("~") e considerado como tail da corrida.
  final bool isPartial;

  const KmSplit({
    required this.kmIndex,
    required this.durationS,
    this.avgPaceMinKm,
    this.avgBpm,
    this.maxBpm,
    this.calories,
    this.elevationGain,
    this.elevationLoss,
    this.distanceM,
    this.isPartial = false,
  });

  factory KmSplit.fromJson(Map<String, dynamic> j) => KmSplit(
        kmIndex: (j['kmIndex'] as num).toInt(),
        durationS: (j['durationS'] as num).toInt(),
        avgPaceMinKm: j['avgPaceMinKm'] as String?,
        avgBpm: (j['avgBpm'] as num?)?.toInt(),
        maxBpm: (j['maxBpm'] as num?)?.toInt(),
        calories: (j['calories'] as num?)?.toInt(),
        elevationGain: (j['elevationGain'] as num?)?.toDouble(),
        elevationLoss: (j['elevationLoss'] as num?)?.toDouble(),
        distanceM: (j['distanceM'] as num?)?.toDouble(),
        isPartial: (j['isPartial'] as bool?) ?? false,
      );

  /// Payload pra enviar splits[] no PATCH /runs/:id/complete. NÃO inclui
  /// calorias — server calcula a partir do peso do perfil.
  Map<String, dynamic> toCompletePayload() => {
        'kmIndex': kmIndex,
        'durationS': durationS,
        'avgPaceMinKm': avgPaceMinKm ?? formattedPace,
        if (avgBpm != null) 'avgBpm': avgBpm,
        if (maxBpm != null) 'maxBpm': maxBpm,
        if (elevationGain != null) 'elevationGain': elevationGain,
        if (elevationLoss != null) 'elevationLoss': elevationLoss,
        if (distanceM != null) 'distanceM': distanceM,
        if (isPartial) 'isPartial': true,
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
/// intervalo do km) e elevação ganho/perda com HISTERESE de 3m.
/// Calorias ficam null — server preenche no complete.
///
/// Histerese (padrão Garmin): mantém uma altitude de referência e só
/// contabiliza ganho/perda quando o acumulado desde a referência passa de
/// ±3m. Antes somávamos cada delta positivo bruto — ruído GPS de ±5-15m
/// fabricava dezenas de metros de "ganho" em percurso plano (TF 82).
const double _elevHysteresisM = 3.0;

List<KmSplit> computeKmSplits(List<GpsPoint> points) {
  if (points.length < 2) return const [];
  final splits = <KmSplit>[];
  double cumDist = 0;
  int kmReached = 0;
  int kmStartTs = points.first.ts;
  double kmStartDist = 0;
  int bpmSum = 0;
  int bpmCount = 0;
  int bpmMax = 0;
  double elevGain = 0;
  double elevLoss = 0;
  double? refAlt = points.first.altitude;
  bool anyAlt = points.first.altitude != null;

  for (int i = 1; i < points.length; i++) {
    final p0 = points[i - 1];
    final p1 = points[i];
    cumDist += _haversineM(p0.lat, p0.lng, p1.lat, p1.lng);
    if (p1.bpm != null && p1.bpm! > 0) {
      bpmSum += p1.bpm!;
      bpmCount++;
      if (p1.bpm! > bpmMax) bpmMax = p1.bpm!;
    }
    if (p1.altitude != null) {
      anyAlt = true;
      if (refAlt == null) {
        refAlt = p1.altitude;
      } else {
        final delta = p1.altitude! - refAlt;
        if (delta >= _elevHysteresisM) {
          elevGain += delta;
          refAlt = p1.altitude;
        } else if (delta <= -_elevHysteresisM) {
          elevLoss += -delta;
          refAlt = p1.altitude;
        }
      }
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
          maxBpm: bpmMax > 0 ? bpmMax : null,
          elevationGain: anyAlt ? double.parse(elevGain.toStringAsFixed(1)) : null,
          elevationLoss: anyAlt ? double.parse(elevLoss.toStringAsFixed(1)) : null,
        ));
      }
      kmReached++;
      kmStartTs = p1.ts;
      kmStartDist = cumDist;
      bpmSum = 0;
      bpmCount = 0;
      bpmMax = 0;
      elevGain = 0;
      elevLoss = 0;
    }
  }
  // Split parcial final: cobre o tail da corrida que não fechou 1km
  // completo (ex: 3.04km → split de 40m). Sem isso, o tail sumia
  // (UI mostrava só KM1+KM2+KM3 completos). Threshold 30m: GPS drift
  // típico parado é ~10-15m; 30m+ já indica deslocamento real (caminhada
  // ~30s). Mantém o tradeoff: melhor mostrar um partial ocasional de
  // drift do que sumir com 40m reais que o user andou.
  final leftoverM = cumDist - kmStartDist;
  if (leftoverM > 30) {
    final lastTs = points.last.ts;
    final leftoverS = (lastTs - kmStartTs) / 1000.0;
    if (leftoverS > 0) {
      // Pace normalizado por km (1000m / distância parcial × tempo parcial).
      // Ex: 40m em 12s → 5:00/km. Mantém formato mm:ss/km no avgPaceMinKm
      // pra UI renderizar igual aos splits completos.
      final paceSecPerKm = (leftoverS / leftoverM) * 1000.0;
      // Total arredondado ANTES de separar ((%60).round()→60 dava "5:60").
      final paceTotal = paceSecPerKm.round();
      final paceMin = paceTotal ~/ 60;
      final paceSec = paceTotal % 60;
      splits.add(KmSplit(
        kmIndex: kmReached,
        durationS: leftoverS.round(),
        avgPaceMinKm:
            '${paceMin.toString().padLeft(2, '0')}:${paceSec.toString().padLeft(2, '0')}',
        avgBpm: bpmCount > 0 ? (bpmSum / bpmCount).round() : null,
        maxBpm: bpmMax > 0 ? bpmMax : null,
        elevationGain: anyAlt ? double.parse(elevGain.toStringAsFixed(1)) : null,
        elevationLoss: anyAlt ? double.parse(elevLoss.toStringAsFixed(1)) : null,
        distanceM: leftoverM,
        isPartial: true,
      ));
    }
  }
  return splits;
}

/// Pace instantâneo (min/km) pela distância real / tempo real dos últimos
/// [windowMeters]. Robusto contra drift de GPS parado — diferente do
/// `pos.speed` cru que gera pace absurdo (~235 min/km) quando a velocidade
/// reportada é minúscula com o atleta parado.
///
/// Retorna null (→ UI mostra "--:--") quando:
///   - há menos de 2 pontos
///   - a janela juntou < [minDistMeters] (parado / drift)
///   - o pace resultante passa de [maxPaceMinKm] (não é corrida)
///
/// [maxWindowMs] limita quantos segundos pra trás varremos — quando parado,
/// os pontos não acumulam [windowMeters] e sem esse cap o loop percorreria
/// a run inteira (a lista de pontos cresce indefinidamente).
double? rollingPaceMinKm(
  List<GpsPoint> points, {
  double windowMeters = 30,
  int maxWindowMs = 30000,
  double minDistMeters = 8,
  double maxPaceMinKm = 20,
}) {
  if (points.length < 2) return null;
  final lastTs = points.last.ts;
  double dist = 0;
  int startTs = lastTs;
  for (int i = points.length - 1; i > 0; i--) {
    final a = points[i - 1];
    final b = points[i];
    if (lastTs - a.ts > maxWindowMs) break;
    dist += _haversineM(a.lat, a.lng, b.lat, b.lng);
    startTs = a.ts;
    if (dist >= windowMeters) break;
  }
  if (dist < minDistMeters) return null;
  final dtSec = (lastTs - startTs) / 1000.0;
  if (dtSec <= 0) return null;
  final speedMps = dist / dtSec;
  if (speedMps <= 0) return null;
  final pace = (1000 / speedMps) / 60;
  if (pace > maxPaceMinKm) return null;
  return pace;
}

/// Classificação de esforço da corrida de avaliação (computada no server).
class AssessmentResult {
  /// % da reserva de FC (Karvonen). ≥85 = esforço máximo.
  final int? pctHrr;
  /// Drift cardíaco Pa:Hr 1ª vs 2ª metade (%). >5% = insustentável.
  final double? cardiacDriftPct;
  final String? effortLabel; // 'confortavel'|'moderado'|'forte'|'maximo'
  /// Pace base (easy) estimado a partir do medido + esforço.
  final String? easyPaceMinKm;

  const AssessmentResult({
    this.pctHrr,
    this.cardiacDriftPct,
    this.effortLabel,
    this.easyPaceMinKm,
  });

  static AssessmentResult? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return AssessmentResult(
      pctHrr: (j['pctHrr'] as num?)?.toInt(),
      cardiacDriftPct: (j['cardiacDriftPct'] as num?)?.toDouble(),
      effortLabel: j['effortLabel'] as String?,
      easyPaceMinKm: j['easyPaceMinKm'] as String?,
    );
  }
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
  /// 'indoor' = esteira (distância do painel/estimativa, sem GPS).
  /// Null/'outdoor' = corrida de rua (runs antigas não têm o campo).
  final String? environment;
  /// Alvo da corrida de AVALIAÇÃO (km). Presença marca a run como
  /// assessment — ReportPage mostra o card "Avaliação concluída".
  final double? assessmentTargetKm;
  /// Classificação de esforço da avaliação (server computa no complete:
  /// %HRR Karvonen + drift cardíaco + pace base estimado).
  final AssessmentResult? assessmentResult;
  final List<KmSplit> splits;
  /// Feedback subjetivo submetido pelo user na ReportPage (chips + note).
  /// Substitui o fluxo de checkpoint "solto" — agora a leitura do user
  /// fica vinculada à corrida específica e o cron de domingo agrega da
  /// semana toda. `feedbackAt` indica quando foi enviado.
  final List<CheckpointInput> userFeedback;
  final String? feedbackAt;
  /// TF 79: badges desbloqueados na resposta do PATCH /runs/:id/complete.
  /// Populado APENAS pelo response do complete-run — não persiste, é o sinal
  /// transitório pro cliente abrir BadgePopupModal full-screen antes de ir
  /// pro /report. Em outras leituras de Run, fica `const []`.
  final List<badge_e.Badge> unlockedBadges;

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
    this.environment,
    this.assessmentTargetKm,
    this.assessmentResult,
    this.splits = const [],
    this.userFeedback = const [],
    this.feedbackAt,
    this.unlockedBadges = const [],
  });

  factory Run.fromJson(Map<String, dynamic> j) => Run(
    id: j['id'] as String,
    status: j['status'] as String,
    type: j['type'] as String,
    targetPace: j['targetPace'] as String?,
    targetDistance: j['targetDistance'] as String?,
    distanceM: (j['distanceM'] as num).toDouble(),
    durationS: (j['durationS'] as num).toInt(),
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
    environment: j['environment'] as String?,
    assessmentTargetKm: (j['assessmentTargetKm'] as num?)?.toDouble(),
    assessmentResult: AssessmentResult.fromJson(
      j['assessmentResult'] as Map<String, dynamic>?,
    ),
    splits: j['splits'] != null
        ? (j['splits'] as List)
            .map((e) => KmSplit.fromJson(e as Map<String, dynamic>))
            .toList()
        : const [],
    userFeedback: j['userFeedback'] != null
        ? (j['userFeedback'] as List)
            .map((e) => CheckpointInput.fromJson(e as Map<String, dynamic>))
            .toList()
        : const [],
    feedbackAt: j['feedbackAt'] as String?,
    unlockedBadges: j['unlockedBadges'] != null
        ? (j['unlockedBadges'] as List)
            .map((e) => badge_e.Badge.fromJson(e as Map<String, dynamic>))
            .toList()
        : const [],
  );
}
