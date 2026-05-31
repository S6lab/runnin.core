/// Benefício de parceiro do usuário (item de `GET /subscriptions/benefits`).
/// Junta a assinatura (collection `subscriptions`) com o plano concedido.
class Benefit {
  final String id; // subscription id
  final String provider; // 'claro', 's6lab', ...
  final String serviceId; // id do serviço no parceiro (resolve o plano no BE)
  final String status;
  final String? activatedAt;
  final String planName; // ex: "Pro by Claro"
  final String priceLabel; // ex: "Incluso"
  final String periodLabel; // ex: "no plano Claro"

  const Benefit({
    required this.id,
    required this.provider,
    required this.serviceId,
    required this.status,
    this.activatedAt,
    required this.planName,
    required this.priceLabel,
    required this.periodLabel,
  });

  bool get isActivated => activatedAt != null && activatedAt!.isNotEmpty;

  /// Nome de exibição do parceiro (ex: 'claro' → 'Claro').
  String get providerName {
    if (provider.isEmpty) return 'Parceiro';
    if (provider == 's6lab') return 'runnin';
    return provider[0].toUpperCase() + provider.substring(1);
  }

  factory Benefit.fromJson(Map<String, dynamic> j) {
    final sub = (j['subscription'] as Map<String, dynamic>?) ?? const {};
    final plan = (j['plan'] as Map<String, dynamic>?) ?? const {};
    return Benefit(
      id: sub['id'] as String? ?? '',
      provider: sub['provider'] as String? ?? '',
      serviceId: sub['serviceId'] as String? ?? '',
      status: sub['status'] as String? ?? '',
      activatedAt: sub['activatedAt'] as String?,
      planName: plan['name'] as String? ?? 'Plano Pro',
      priceLabel: plan['priceLabel'] as String? ?? '',
      periodLabel: plan['periodLabel'] as String? ?? '',
    );
  }
}
