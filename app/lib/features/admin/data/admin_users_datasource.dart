import 'package:runnin/core/network/api_client.dart';

class AdminUserSummary {
  final String id;
  final String? email;
  final String? name;
  final String subscriptionPlanId;
  final bool onboarded;

  AdminUserSummary({
    required this.id,
    required this.email,
    required this.name,
    required this.subscriptionPlanId,
    required this.onboarded,
  });

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) => AdminUserSummary(
        id: json['id'] as String,
        email: json['email'] as String?,
        name: json['name'] as String?,
        subscriptionPlanId: (json['subscriptionPlanId'] as String?) ?? 'freemium',
        onboarded: (json['onboarded'] as bool?) ?? false,
      );
}

class AdminUsersDatasource {
  Future<List<AdminUserSummary>> list({String? search, int limit = 50}) async {
    final res = await apiClient.get<Map<String, dynamic>>(
      '/admin/users',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
      },
    );
    final users = (res.data?['users'] as List?) ?? [];
    return users
        .map((u) => AdminUserSummary.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<void> setPlan({required String userId, required String plan}) async {
    await apiClient.patch<void>('/admin/users/$userId/plan', data: {'plan': plan});
  }
}
