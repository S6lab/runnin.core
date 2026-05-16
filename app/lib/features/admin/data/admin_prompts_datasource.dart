import 'package:runnin/core/network/api_client.dart';

class AdminPromptsDatasource {
  Future<Map<String, dynamic>> getDefaults() async {
    final res = await apiClient.get<Map<String, dynamic>>('/admin/prompts/defaults');
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> preview({
    required String builder,
    bool runLlm = false,
    Map<String, dynamic>? fixture,
  }) async {
    final res = await apiClient.post<Map<String, dynamic>>(
      '/admin/prompts/preview',
      data: {
        'builder': builder,
        'runLlm': runLlm,
        if (fixture != null) 'fixture': fixture,
      },
    );
    return res.data ?? {};
  }

  Future<void> invalidateCache() async {
    await apiClient.post<void>('/admin/prompts/invalidate-cache');
  }
}
