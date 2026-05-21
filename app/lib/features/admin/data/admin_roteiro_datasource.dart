import 'package:runnin/core/network/api_client.dart';

/// Defaults + cache do roteiro de fases (Dossiê 4). O override é escrito
/// direto no Firestore (app_config/roteiro_templates) pela página de admin;
/// o backend só serve os defaults e invalida o cache de 60s.
class AdminRoteiroDatasource {
  Future<Map<String, dynamic>> getDefaults() async {
    final res = await apiClient
        .get<Map<String, dynamic>>('/admin/roteiro-templates/defaults');
    final data = res.data ?? const {};
    return (data['templates'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> invalidateCache() async {
    await apiClient.post<void>('/admin/roteiro-templates/invalidate-cache');
  }
}
