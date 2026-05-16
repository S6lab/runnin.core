import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

class CoachMessageLog {
  final String id;
  final String author;
  final String? event;
  final String text;
  final double? kmAtTime;
  final String? paceAtTime;
  final int? bpmAtTime;
  final String createdAt;

  const CoachMessageLog({
    required this.id,
    required this.author,
    this.event,
    required this.text,
    this.kmAtTime,
    this.paceAtTime,
    this.bpmAtTime,
    required this.createdAt,
  });

  factory CoachMessageLog.fromJson(Map<String, dynamic> j) => CoachMessageLog(
    id: j['id'] as String,
    author: j['author'] as String,
    event: j['event'] as String?,
    text: j['text'] as String,
    kmAtTime: (j['kmAtTime'] as num?)?.toDouble(),
    paceAtTime: j['paceAtTime'] as String?,
    bpmAtTime: j['bpmAtTime'] as int?,
    createdAt: j['createdAt'] as String,
  );
}

class CoachMessageRemoteDatasource {
  final Dio _dio;
  CoachMessageRemoteDatasource() : _dio = apiClient;

  Future<List<CoachMessageLog>> getMessages(String runId) async {
    final res = await _dio.get('/coach/messages/$runId');
    final data = res.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    return items
        .map((e) => CoachMessageLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
