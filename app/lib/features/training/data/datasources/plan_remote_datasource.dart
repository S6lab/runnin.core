import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

class PlanRemoteDatasource {
  final Dio _dio;
  PlanRemoteDatasource() : _dio = apiClient;

  // Guard contra disparos simultâneos de generatePlan. Antes: hard refresh
  // ou clique duplo no botão "GERAR PLANO" disparava 2 POSTs paralelos; o
  // server retornava 409 no segundo (race do checkout no Firestore). Era
  // inofensivo mas ruidoso nos logs e confundia o user (toast de erro).
  static bool _generateInFlight = false;

  Future<Plan?> getCurrentPlan() async {
    try {
      final res = await _dio.get('/plans/current');
      return Plan.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String> generatePlan({
    required String goal,
    required String level,
    int? frequency,
    int? weeksCount,
    String? startDate, // ISO YYYY-MM-DD; D0 escolhida no onboarding
    bool confirmOverwrite = false,
  }) async {
    if (_generateInFlight) {
      // ignore: avoid_print
      print('plan.generate.skipped reason=in_flight');
      throw DioException(
        requestOptions: RequestOptions(path: '/plans/generate'),
        message: 'Geração já em andamento — aguarda a primeira terminar.',
        type: DioExceptionType.cancel,
      );
    }
    _generateInFlight = true;
    try {
      final res = await _dio.post(
        '/plans/generate',
        queryParameters: confirmOverwrite ? {'confirmOverwrite': '1'} : null,
        data: {
          'goal': goal,
          'level': level,
          'weeksCount': ?weeksCount,
          'frequency': ?frequency,
          'startDate': ?startDate,
        },
      );
      return (res.data as Map<String, dynamic>)['planId'] as String;
    } finally {
      _generateInFlight = false;
    }
  }

  Future<Plan> getPlanById(String planId) async {
    final res = await _dio.get('/plans/$planId');
    return Plan.fromJson(res.data as Map<String, dynamic>);
  }
}
