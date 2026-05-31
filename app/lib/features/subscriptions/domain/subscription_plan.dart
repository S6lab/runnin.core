/// Espelha PlanFeatures do backend (server/src/modules/subscriptions/domain/plan-features.ts).
/// Manter em sync — adicionar feature aqui sempre que adicionar lá.
class PlanFeatures {
  final bool runTracking;
  final bool freeRun;
  final bool plannedRun;
  final bool generatePlan;
  final bool weeklyReports;
  final bool planRevisions;
  final bool coachChat;
  final bool coachLive;
  final bool coachVoiceDuringRun;
  final bool healthZones;
  final bool examsOCR;
  final bool wearableSync;
  final bool shareWithOverlay;
  final bool historyExport;

  const PlanFeatures({
    this.runTracking = true,
    this.freeRun = true,
    this.plannedRun = false,
    this.generatePlan = false,
    this.weeklyReports = false,
    this.planRevisions = false,
    this.coachChat = false,
    this.coachLive = false,
    this.coachVoiceDuringRun = false,
    this.healthZones = false,
    this.examsOCR = false,
    this.wearableSync = false,
    this.shareWithOverlay = true,
    this.historyExport = false,
  });

  factory PlanFeatures.fromJson(Map<String, dynamic> j) => PlanFeatures(
        runTracking: j['runTracking'] as bool? ?? true,
        freeRun: j['freeRun'] as bool? ?? true,
        plannedRun: j['plannedRun'] as bool? ?? false,
        generatePlan: j['generatePlan'] as bool? ?? false,
        weeklyReports: j['weeklyReports'] as bool? ?? false,
        planRevisions: j['planRevisions'] as bool? ?? false,
        coachChat: j['coachChat'] as bool? ?? false,
        coachLive: j['coachLive'] as bool? ?? false,
        coachVoiceDuringRun: j['coachVoiceDuringRun'] as bool? ?? false,
        healthZones: j['healthZones'] as bool? ?? false,
        examsOCR: j['examsOCR'] as bool? ?? false,
        wearableSync: j['wearableSync'] as bool? ?? false,
        shareWithOverlay: j['shareWithOverlay'] as bool? ?? true,
        historyExport: j['historyExport'] as bool? ?? false,
      );
}

class PlanLimits {
  final int plansPerMonth;
  final int examsPerMonth;
  final int coachMessagesPerDay;
  final int weeklyReportsPerMonth;

  const PlanLimits({
    this.plansPerMonth = 0,
    this.examsPerMonth = 0,
    this.coachMessagesPerDay = 0,
    this.weeklyReportsPerMonth = 0,
  });

  factory PlanLimits.fromJson(Map<String, dynamic> j) => PlanLimits(
        plansPerMonth: (j['plansPerMonth'] as num?)?.toInt() ?? 0,
        examsPerMonth: (j['examsPerMonth'] as num?)?.toInt() ?? 0,
        coachMessagesPerDay: (j['coachMessagesPerDay'] as num?)?.toInt() ?? 0,
        weeklyReportsPerMonth:
            (j['weeklyReportsPerMonth'] as num?)?.toInt() ?? 0,
      );
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String priceLabel;
  final String periodLabel;
  final PlanFeatures features;
  final PlanLimits limits;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.periodLabel,
    required this.features,
    required this.limits,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        priceLabel: j['priceLabel'] as String? ?? '',
        periodLabel: j['periodLabel'] as String? ?? '',
        features: PlanFeatures.fromJson(
          j['features'] as Map<String, dynamic>? ?? {},
        ),
        limits: PlanLimits.fromJson(
          j['limits'] as Map<String, dynamic>? ?? {},
        ),
      );

  static const freemiumFallback = SubscriptionPlan(
    id: 'freemium',
    name: 'Gratuito',
    priceLabel: 'Grátis',
    periodLabel: '',
    features: PlanFeatures(),
    limits: PlanLimits(),
  );
}

class UserSubscription {
  final String planId;
  final SubscriptionPlan plan;
  const UserSubscription({required this.planId, required this.plan});

  factory UserSubscription.fromJson(Map<String, dynamic> j) => UserSubscription(
        planId: j['planId'] as String,
        plan: SubscriptionPlan.fromJson(j['plan'] as Map<String, dynamic>),
      );
}
