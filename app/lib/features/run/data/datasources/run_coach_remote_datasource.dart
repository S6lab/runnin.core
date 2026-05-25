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
    /// Duração (s) do km que acabou de cruzar (não acumulado). Server usa
    /// pra coach reportar "1 km em X min" + estimar calorias do km.
    int? kmDurationS,
    /// FC média (bpm) durante o km que acabou de cruzar. Null se sem wearable.
    int? kmAvgBpm,
    /// ID da PlanSession sendo executada. Server usa pra puxar briefing
    /// completo (notes, segments, nutrição) no contexto do LLM. Null em
    /// Free Run.
    String? planSessionId,
    /// Índice (0-based) do segment ativo dentro da PlanSession. Setado
    /// pelo bloc em eventos segment_*. Server resolve o segment alvo
    /// pra ancorar a fala do coach na fase correta.
    int? currentSegmentIndex,
    /// Histórico de splits já fechados, enviado no evento `km_analysis`
    /// pra LLM comparar progressão km-a-km. Cada item: {km, paceMinKm,
    /// durationS, avgBpm?}. Server passa direto pro prompt.
    List<Map<String, dynamic>>? recentSplits,
    /// Snapshot de clima capturado pelo app no início da corrida.
    /// Opcional — coach considera quando presente, ignora se null.
    double? temperatureC,
    int? humidityPercent,
    double? windKmh,
  }) async* {
    final res = await _dio.post<Object>(
      '/coach/message',
      data: {
        'runId': ?runId,
        'event': event,
        'runType': ?runType,
        'currentPaceMinKm': currentPaceMinKm,
        'distanceM': distanceM,
        'elapsedS': elapsedS,
        'targetPaceMinKm': ?targetPaceMinKm,
        'targetDistance': ?targetDistance,
        'kmReached': ?kmReached,
        'kmDurationS': ?kmDurationS,
        'kmAvgBpm': ?kmAvgBpm,
        'planSessionId': ?planSessionId,
        'currentSegmentIndex': ?currentSegmentIndex,
        'recentSplits': ?recentSplits,
        'temperatureC': ?temperatureC,
        'humidityPercent': ?humidityPercent,
        'windKmh': ?windKmh,
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
        validateStatus: (status) => status != null && (status < 400 || status == 204),
      ),
    );

    // Decision layer no server pode skipar a mensagem (frequency=silent, DND, etc).
    // Server retorna 204 No Content — apenas encerra o stream sem yield.
    if (res.statusCode == 204) return;

    final body = res.data;
    if (body is! ResponseBody) {
      throw Exception('Resposta invalida do coach em tempo real.');
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
