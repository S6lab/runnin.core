import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:runnin/core/network/api_client.dart';

class UserProfile {
  final String id;
  /// Redundância intencional do uid pra trace cross-system. Igual ao [id].
  final String authId;
  /// Email do Firebase Auth — populado no provision. Null se user
  /// autenticou só por phone.
  final String? email;
  /// Phone E.164 do Firebase Auth — populado no provision. Null se user
  /// autenticou só por email/social.
  final String? phone;
  final String name;
  final String level;
  final String goal;
  final int frequency;
  final String? birthDate;
  final String? weight;
  final String? height;
  final bool hasWearable;
  final List<String> medicalConditions;
  final String coachVoiceId;
  final bool onboarded;
  final bool premium;
  final DateTime? premiumUntil;
  final DateTime? lastOnboardingAt;
  // Phase 4 foundation new fields
  final String? gender;        // 'male' | 'female' | 'other' | 'na'
  final String? runPeriod;     // 'manha' | 'tarde' | 'noite'
  final String? wakeTime;
  final String? sleepTime;
  final bool? coachIntroSeen;
  final int? restingBpm;
  final int? maxBpm;
  final Map<String, bool>? preRunAlerts;
  final String? coachPersonality;
  final String? coachMessageFrequency;
  final Map<String, bool>? coachFeedbackEnabled;
  final bool? allowCriticalAlertsInSilent;
  final Map<String, bool>? notificationsEnabled;
  final Map<String, String>? dndWindow;
  final String? uiSkin;
  final String? textScale;
  final String? unitsSystem;
  final String? paceFormat;
  final String? timeFormat;

  const UserProfile({
    required this.id,
    required this.authId,
    this.email,
    this.phone,
    required this.name,
    required this.level,
    required this.goal,
    required this.frequency,
    required this.birthDate,
    required this.weight,
    required this.height,
    required this.hasWearable,
    required this.medicalConditions,
    required this.coachVoiceId,
    required this.onboarded,
    required this.premium,
    required this.premiumUntil,
    required this.lastOnboardingAt,
    this.gender,
    this.runPeriod,
    this.wakeTime,
    this.sleepTime,
    this.coachIntroSeen,
    this.restingBpm,
    this.maxBpm,
    this.preRunAlerts,
    this.coachPersonality,
    this.coachMessageFrequency,
    this.coachFeedbackEnabled,
    this.allowCriticalAlertsInSilent,
    this.notificationsEnabled,
    this.dndWindow,
    this.uiSkin,
    this.textScale,
    this.unitsSystem,
    this.paceFormat,
    this.timeFormat,
  });

  bool get isPro {
    if (premium) return true;
    final until = premiumUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String,
    // authId pode estar ausente em docs legados (pre-fix). Fallback pro id
    // mantém o invariante "authId == uid".
    authId: (j['authId'] as String?) ?? (j['id'] as String),
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    name: j['name'] as String,
    level: j['level'] as String,
    goal: j['goal'] as String,
    frequency: (j['frequency'] as num).toInt(),
    birthDate: j['birthDate'] as String?,
    weight: j['weight'] as String?,
    height: j['height'] as String?,
    hasWearable: j['hasWearable'] as bool? ?? false,
    medicalConditions: (j['medicalConditions'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    coachVoiceId: j['coachVoiceId'] as String? ?? 'coach-bruno',
    onboarded: j['onboarded'] as bool? ?? false,
    premium: j['premium'] as bool? ?? false,
    premiumUntil: j['premiumUntil'] is String
        ? DateTime.tryParse(j['premiumUntil'] as String)
        : null,
    lastOnboardingAt: j['lastOnboardingAt'] is String
        ? DateTime.tryParse(j['lastOnboardingAt'] as String)
        : null,
    gender: j['gender'] as String?,
    runPeriod: j['runPeriod'] as String?,
    wakeTime: j['wakeTime'] as String?,
    sleepTime: j['sleepTime'] as String?,
    coachIntroSeen: j['coachIntroSeen'] as bool?,
    // Firestore JS SDK serializa todo Number como Double na wire — então
    // mesmo um Math.round() server-side pode chegar como 45.0 no JSON.
    // `as int?` estoura TypeError; (num).toInt() funciona em ambos casos.
    restingBpm: (j['restingBpm'] as num?)?.toInt(),
    maxBpm: (j['maxBpm'] as num?)?.toInt(),
    preRunAlerts: (j['preRunAlerts'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as bool)),
    coachPersonality: j['coachPersonality'] as String?,
    coachMessageFrequency: j['coachMessageFrequency'] as String?,
    coachFeedbackEnabled: (j['coachFeedbackEnabled'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as bool)),
    allowCriticalAlertsInSilent: j['allowCriticalAlertsInSilent'] as bool?,
    notificationsEnabled: (j['notificationsEnabled'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as bool)),
    dndWindow: (j['dndWindow'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as String)),
    uiSkin: j['uiSkin'] as String?,
    textScale: j['textScale'] as String?,
    unitsSystem: j['unitsSystem'] as String?,
    paceFormat: j['paceFormat'] as String?,
    timeFormat: j['timeFormat'] as String?,
  );
}

class UserRemoteDatasource {
  final Dio _dio;
  UserRemoteDatasource() : _dio = apiClient;

  Future<UserProfile?> getMe() async {
    try {
      final res = await _dio.get('/users/me');
      return UserProfile.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 404) return null;
      rethrow;
    }
  }

  Future<UserProfile> provisionMe({String? name}) async {
    final fallbackName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final effectiveName = (name ?? fallbackName);

    final res = await _dio.post(
      '/users/provision',
      data: {
        if (effectiveName != null && effectiveName.isNotEmpty)
          'name': effectiveName,
      },
    );
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<UserProfile> completeOnboarding({
    required String name,
    required String level,
    required String goal,
    required int frequency,
    String? birthDate,
    String? weight,
    String? height,
    String? targetPace,
    bool hasWearable = false,
    List<String> medicalConditions = const [],
    String? gender,        // 'male' | 'female' | 'other' | 'na'
    String? runPeriod,     // 'manha' | 'tarde' | 'noite'
    String? wakeTime,      // "HH:MM"
    String? sleepTime,     // "HH:MM"
  }) async {
    final res = await _dio.post(
      '/users/onboarding',
      data: {
        'name': name,
        'level': level,
        'goal': goal,
        'frequency': frequency,
        'birthDate': birthDate,
        'weight': weight,
        'height': height,
        // null-aware: targetPace não é mais coletado no onboarding (migrou pra
        // jornada de plano em TREINO). Omitir quando null — o server rejeita
        // null explícito mesmo sendo opcional.
        'targetPace': ?targetPace,
        'hasWearable': hasWearable,
        'medicalConditions': medicalConditions,
        'gender': ?gender,
        'runPeriod': ?runPeriod,
        'wakeTime': ?wakeTime,
        'sleepTime': ?sleepTime,
      },
    );
    final data = res.data as Map<String, dynamic>;
    return UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserProfile> patchMe({
    String? name,
    String? level,
    String? goal,
    int? frequency,
    List<int>? availableDays,
    String? birthDate,
    String? weight,
    String? height,
    bool? hasWearable,
    List<String>? medicalConditions,
    String? coachVoiceId,
    bool? onboarded,
    bool? coachIntroSeen,
    String? gender,
    String? runPeriod,
    String? wakeTime,
    String? sleepTime,
    int? restingBpm,
    int? maxBpm,
    Map<String, bool>? preRunAlerts,
    String? uiSkin,
    String? textScale,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'level': level,
      'goal': goal,
      'frequency': frequency,
      'availableDays': availableDays,
      'birthDate': birthDate,
      'weight': weight,
      'height': height,
      'hasWearable': hasWearable,
      'medicalConditions': medicalConditions,
      'coachVoiceId': coachVoiceId,
      'onboarded': onboarded,
      'coachIntroSeen': coachIntroSeen,
      'gender': gender,
      'runPeriod': runPeriod,
      'wakeTime': wakeTime,
      'sleepTime': sleepTime,
      'restingBpm': restingBpm,
      'maxBpm': maxBpm,
      'preRunAlerts': preRunAlerts,
      'uiSkin': uiSkin,
      'textScale': textScale,
    }..removeWhere((_, value) => value == null);

    final res = await _dio.patch('/users/me', data: data);
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<UserProfile> activateTrial() async {
    final res = await _dio.post('/users/me/trial');
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }
}
