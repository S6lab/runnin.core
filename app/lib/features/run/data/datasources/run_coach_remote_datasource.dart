import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

class RunCoachRemoteDatasource {
  final Dio _dio;
  RunCoachRemoteDatasource() : _dio = apiClient;

  Stream<String> streamCoachCue({
    required String runId,
    required String event,
    required double currentPaceMinKm,
    required double distanceM,
    required int elapsedS,
    double? targetPaceMinKm,
    int? kmReached,
  }) async* {
    final res = await _dio.post<Object>(
      '/coach/message',
      data: {
        'runId': runId,
        'event': event,
        'currentPaceMinKm': currentPaceMinKm,
        'targetPaceMinKm': targetPaceMinKm,
        'distanceM': distanceM,
        'elapsedS': elapsedS,
        'kmReached': kmReached,
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final body = res.data;
    if (body is! ResponseBody) {
      throw Exception('Resposta invalida do coach em tempo real.');
    }

    await for (final line in body.stream
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
          yield text;
        }
      }
    }
  }
}
