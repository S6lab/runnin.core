import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/admin/domain/registry_entries.dart';

/// Datasource read-only que consome endpoints `GET /admin/*/registry|moments|
/// crons|plans-catalog|constants/plan-rules|wiring-status`. O server é a
/// fonte de verdade — admin do app só renderiza o que vem.
class AdminRegistryDatasource {
  Future<List<PromptRegistryEntry>> listPrompts() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/prompts/registry');
    final list = (res.data?['prompts'] as List?) ?? const [];
    return list
        .map((e) => PromptRegistryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CoachMoment>> listMoments() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/coach-ai/moments');
    final list = (res.data?['moments'] as List?) ?? const [];
    return list
        .map((e) => CoachMoment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CronEntry>> listCrons() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/crons');
    final list = (res.data?['crons'] as List?) ?? const [];
    return list
        .map((e) => CronEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SubscriptionPlanOption>> listPlansCatalog() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/users/plans-catalog');
    final list = (res.data?['plans'] as List?) ?? const [];
    return list
        .map((e) => SubscriptionPlanOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PlanRulesSnapshot> getPlanRules() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/constants/plan-rules');
    return PlanRulesSnapshot.fromJson(res.data ?? const {});
  }

  Future<WiringStatusPayload> getWiringStatus() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/wiring-status');
    return WiringStatusPayload.fromJson(res.data ?? const {});
  }
}
