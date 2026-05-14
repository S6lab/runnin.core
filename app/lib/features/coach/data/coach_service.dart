import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

class CoachBriefing {
  final String briefingId;
  final String text;
  final String? audioBase64;
  final String? audioMimeType;
  final DateTime generatedAt;

  const CoachBriefing({
    required this.briefingId,
    required this.text,
    this.audioBase64,
    this.audioMimeType,
    required this.generatedAt,
  });

  factory CoachBriefing.fromJson(Map<String, dynamic> json) => CoachBriefing(
        briefingId: json['briefingId'] as String,
        text: json['text'] as String,
        audioBase64: json['audioBase64']?.toString(),
        audioMimeType: json['audioMimeType']?.toString(),
        generatedAt: DateTime.parse(json['generatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'briefingId': briefingId,
        'text': text,
        'audioBase64': audioBase64,
        'audioMimeType': audioMimeType,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

class CoachAnalysis {
  final String status;
  final String? summary;
  final String? performanceSummary;
  final String? zoneCommentary;
  final String? comparisonToPlan;
  final String? recoveryRecommendation;
  final String? nextSessionPreview;
  final DateTime? generatedAt;

  const CoachAnalysis({
    required this.status,
    this.summary,
    this.performanceSummary,
    this.zoneCommentary,
    this.comparisonToPlan,
    this.recoveryRecommendation,
    this.nextSessionPreview,
    this.generatedAt,
  });

  factory CoachAnalysis.fromJson(Map<String, dynamic> json) => CoachAnalysis(
        status: json['status'] as String? ?? 'pending',
        summary: json['summary']?.toString(),
        performanceSummary: json['performanceSummary']?.toString(),
        zoneCommentary: json['zoneCommentary']?.toString(),
        comparisonToPlan: json['comparisonToPlan']?.toString(),
        recoveryRecommendation: json['recoveryRecommendation']?.toString(),
        nextSessionPreview: json['nextSessionPreview']?.toString(),
        generatedAt: json['generatedAt'] != null
            ? DateTime.parse(json['generatedAt'] as String)
            : null,
      );

  bool get isReady =>
      status == 'ready' && (summary?.trim().isNotEmpty ?? false);
}

class CoachVoiceSettings {
  final bool enabled;
  final String voiceId;
  final double volume;
  final String alertFrequency;

  const CoachVoiceSettings({
    this.enabled = true,
    this.voiceId = 'coach-bruno',
    this.volume = 1.0,
    this.alertFrequency = 'standard',
  });

  factory CoachVoiceSettings.fromJson(Map<String, dynamic> json) =>
      CoachVoiceSettings(
        enabled: json['enabled'] as bool? ?? true,
        voiceId: json['voiceId']?.toString() ?? 'coach-bruno',
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        alertFrequency: json['alertFrequency']?.toString() ?? 'standard',
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'voiceId': voiceId,
        'volume': volume,
        'alertFrequency': alertFrequency,
      };
}

class CoachService {
  final Dio _dio;
  CoachService() : _dio = apiClient;

  Future<CoachBriefing> fetchBriefing(String userId, String sessionType,
      double distanceKm, String? targetPace, String? planSessionId) async {
    final res = await _dio.post('/coach/briefing', data: {
      'userId': userId,
      'sessionType': sessionType,
      'distanceKm': distanceKm,
      'targetPace': targetPace,
      'planSessionId': planSessionId,
    });

    return CoachBriefing.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachAnalysis> fetchAnalysis(String userId, String runId) async {
    final res = await _dio.get('/coach/report/$runId');

    return CoachAnalysis.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CoachVoiceSettings> fetchVoiceSettings(String userId) async {
    final res = await _dio.get('/coach/voice-settings/$userId');

    return CoachVoiceSettings.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateVoiceSettings(
      String userId, CoachVoiceSettings settings) async {
    await _dio.post('/coach/voice-settings/$userId', data: settings.toJson());
  }

  Future<void> playVoicePreview(String userId, String voiceId,
      {String? text}) async {
    final previewText = text ?? 'Esta é uma prévia da voz do Coach.';
    await _dio.post('/coach/voice-preview', data: {
      'userId': userId,
      'voiceId': voiceId,
      'text': previewText,
    });
  }
}
