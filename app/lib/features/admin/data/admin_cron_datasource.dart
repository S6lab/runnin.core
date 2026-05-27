import 'package:runnin/core/network/api_client.dart';

/// Datasource pros triggers manuais de jobs admin. Hoje só revisão semanal
/// (simula o que o Cloud Scheduler faz aos domingos 06:00 BRT). Endpoint
/// é auth admin via Firebase ID token + custom claim (não X-Cron-Token).
class AdminCronDatasource {
  /// Dispara `RunWeeklyProposalsUseCase` manualmente. Mesma lógica do cron
  /// dominical — enfileira tasks por user com plano ativo. Idempotente:
  /// não duplica proposta pendente.
  Future<Map<String, dynamic>> triggerWeeklyProposals() async {
    final res = await apiClient.post<Map<String, dynamic>>(
      '/admin/cron/weekly-proposals/trigger',
    );
    return res.data ?? {};
  }
}
