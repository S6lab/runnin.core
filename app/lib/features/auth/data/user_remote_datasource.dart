import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:runnin/core/network/api_client.dart';

class UserProfile {
  final String id;
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

  const UserProfile({
    required this.id,
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
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String,
    name: j['name'] as String,
    level: j['level'] as String,
    goal: j['goal'] as String,
    frequency: j['frequency'] as int,
    birthDate: j['birthDate'] as String?,
    weight: j['weight'] as String?,
    height: j['height'] as String?,
    hasWearable: j['hasWearable'] as bool? ?? false,
    medicalConditions: (j['medicalConditions'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    coachVoiceId: j['coachVoiceId'] as String? ?? 'coach-bruno',
    onboarded: j['onboarded'] as bool? ?? false,
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
    bool hasWearable = false,
    List<String> medicalConditions = const [],
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
        'hasWearable': hasWearable,
        'medicalConditions': medicalConditions,
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
    String? birthDate,
    String? weight,
    String? height,
    bool? hasWearable,
    List<String>? medicalConditions,
    String? coachVoiceId,
    bool? onboarded,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'level': level,
      'goal': goal,
      'frequency': frequency,
      'birthDate': birthDate,
      'weight': weight,
      'height': height,
      'hasWearable': hasWearable,
      'medicalConditions': medicalConditions,
      'coachVoiceId': coachVoiceId,
      'onboarded': onboarded,
    }..removeWhere((_, value) => value == null);

    final res = await _dio.patch('/users/me', data: data);
    return UserProfile.fromJson(res.data as Map<String, dynamic>);
  }
}
