import 'package:runnin/core/network/api_client.dart';

/// Config dinâmica do Coach Live durante a corrida — vive em
/// `app_config/coach_runtime` no Firestore. App fetcha do server (cache 1h
/// Hive); server cacheia 60s. Edição via admin não exige deploy de Dart.
class AdminCoachRuntimeDatasource {
  Future<CoachRuntimeConfigBundle> get() async {
    final res = await apiClient
        .get<Map<String, dynamic>>('/admin/coach/runtime-config');
    return CoachRuntimeConfigBundle.fromJson(res.data ?? const {});
  }

  /// Merge raso no doc Firestore. `cooldownsBy` é substituído inteiro se
  /// vier no payload — passar todos os 4 cooldowns juntos.
  Future<CoachRuntimeConfigBundle> patch(Map<String, dynamic> body) async {
    final res = await apiClient.patch<Map<String, dynamic>>(
      '/admin/coach/runtime-config',
      data: body,
    );
    return CoachRuntimeConfigBundle.fromJson(res.data ?? const {});
  }
}

class CoachRuntimeConfigBundle {
  final CoachRuntimeConfig current;
  final CoachRuntimeConfig defaults;

  const CoachRuntimeConfigBundle({required this.current, required this.defaults});

  factory CoachRuntimeConfigBundle.fromJson(Map<String, dynamic> json) =>
      CoachRuntimeConfigBundle(
        current: CoachRuntimeConfig.fromJson(
          (json['current'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        defaults: CoachRuntimeConfig.fromJson(
          (json['defaults'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

class CoachRuntimeConfig {
  final double checkInDistanceM;
  final int checkInIdleSeconds;
  final int rotationAgeMinutes;
  final int maxReconnectAttempts;
  final CoachCooldowns cooldownsBy;
  final int pendingSendsThrottleMs;
  final int pendingSendsMaxQueue;
  final int suppressCuesGreetingMs;

  const CoachRuntimeConfig({
    required this.checkInDistanceM,
    required this.checkInIdleSeconds,
    required this.rotationAgeMinutes,
    required this.maxReconnectAttempts,
    required this.cooldownsBy,
    required this.pendingSendsThrottleMs,
    required this.pendingSendsMaxQueue,
    required this.suppressCuesGreetingMs,
  });

  factory CoachRuntimeConfig.fromJson(Map<String, dynamic> json) =>
      CoachRuntimeConfig(
        checkInDistanceM:
            (json['checkInDistanceM'] as num?)?.toDouble() ?? 500.0,
        checkInIdleSeconds: (json['checkInIdleSeconds'] as num?)?.toInt() ?? 240,
        rotationAgeMinutes: (json['rotationAgeMinutes'] as num?)?.toInt() ?? 4,
        maxReconnectAttempts:
            (json['maxReconnectAttempts'] as num?)?.toInt() ?? 10,
        cooldownsBy: CoachCooldowns.fromJson(
          (json['cooldownsBy'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        pendingSendsThrottleMs:
            (json['pendingSendsThrottleMs'] as num?)?.toInt() ?? 2000,
        pendingSendsMaxQueue:
            (json['pendingSendsMaxQueue'] as num?)?.toInt() ?? 3,
        suppressCuesGreetingMs:
            (json['suppressCuesGreetingMs'] as num?)?.toInt() ?? 12000,
      );

  Map<String, dynamic> toJson() => {
        'checkInDistanceM': checkInDistanceM,
        'checkInIdleSeconds': checkInIdleSeconds,
        'rotationAgeMinutes': rotationAgeMinutes,
        'maxReconnectAttempts': maxReconnectAttempts,
        'cooldownsBy': cooldownsBy.toJson(),
        'pendingSendsThrottleMs': pendingSendsThrottleMs,
        'pendingSendsMaxQueue': pendingSendsMaxQueue,
        'suppressCuesGreetingMs': suppressCuesGreetingMs,
      };
}

class CoachCooldowns {
  final int paceAlert;
  final int segmentPaceOff;
  final int highBpm;
  final int segmentEnd;

  const CoachCooldowns({
    required this.paceAlert,
    required this.segmentPaceOff,
    required this.highBpm,
    required this.segmentEnd,
  });

  factory CoachCooldowns.fromJson(Map<String, dynamic> json) => CoachCooldowns(
        paceAlert: (json['pace_alert'] as num?)?.toInt() ?? 60,
        segmentPaceOff: (json['segment_pace_off'] as num?)?.toInt() ?? 60,
        highBpm: (json['high_bpm'] as num?)?.toInt() ?? 90,
        segmentEnd: (json['segment_end'] as num?)?.toInt() ?? 999999,
      );

  Map<String, dynamic> toJson() => {
        'pace_alert': paceAlert,
        'segment_pace_off': segmentPaceOff,
        'high_bpm': highBpm,
        'segment_end': segmentEnd,
      };
}
