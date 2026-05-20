import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/subscriptions/domain/benefit.dart';

/// Datasource dos benefícios de parceiro (collection `subscriptions`).
class BenefitRemoteDatasource {
  final Dio _dio;
  BenefitRemoteDatasource({Dio? dio}) : _dio = dio ?? apiClient;

  /// Benefícios do usuário logado (resolvido pelo telefone no backend).
  /// Silencioso: retorna [] em qualquer erro.
  Future<List<Benefit>> listBenefits() async {
    try {
      final res = await _dio.get('/subscriptions/benefits');
      final items = (res.data as Map<String, dynamic>)['items'] as List? ?? [];
      return items
          .map((e) => Benefit.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Ativa o benefício: migra o user pro plano do benefício no servidor.
  Future<void> activate(String subscriptionId) async {
    await _dio.post('/subscriptions/benefits/$subscriptionId/activate');
  }
}
