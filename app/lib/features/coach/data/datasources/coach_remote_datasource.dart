import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

class CoachRemoteDatasource {
  final Dio _dio;
  CoachRemoteDatasource() : _dio = apiClient;

  Future<String> sendMessage(String message) async {
    final res = await _dio.post('/coach/chat', data: {'message': message});
    return (res.data as Map<String, dynamic>)['reply'] as String;
  }
}
