import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

class CoachCue {
  final String text;
  final String? audioBase64;
  final String? audioMimeType;

  const CoachCue({required this.text, this.audioBase64, this.audioMimeType});
}

class RunCoachRemoteDatasource {
  final Dio _dio;
  RunCoachRemoteDatasource() : _dio = apiClient;

  Stream<CoachCue> streamCoachCue({
    String? runId,
    required String event,
    String? runType,
    required double currentPaceMinKm,
    required double distanceM,
    required int elapsedS,
    double? targetPaceMinKm,
    String? targetDistance,
    int? kmReached,
  }) async* {
    final res = await _dio.post<Object>(
      '/coach/message',
      data: {
        'runId': runId,
        'event': event,
        'runType': runType,
        'currentPaceMinKm': currentPaceMinKm,
        'distanceM': distanceM,
        'elapsedS': elapsedS,
        'targetPaceMinKm': targetPaceMinKm,
        'targetDistance': targetDistance,
        'kmReached': kmReached,
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final body = res.data;
    if (body is! ResponseBody) {
      throw Exception('Resposta inválida do coach em tempo real.');
    }

    await for (final line
        in body.stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;

      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final text = decoded['text']?.toString().trim();
        if (text != null && text.isNotEmpty) {
          yield CoachCue(
            text: text,
            audioBase64: decoded['audioBase64']?.toString(),
            audioMimeType: decoded['audioMimeType']?.toString(),
          );
        }
      }
    }
  }
}
