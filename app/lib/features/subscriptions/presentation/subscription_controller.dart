import 'package:flutter/foundation.dart';
import 'package:runnin/features/subscriptions/data/subscription_remote_datasource.dart';
import 'package:runnin/features/subscriptions/domain/subscription_plan.dart';

/// Controller global de subscription/features. Cached em memória,
/// invalidate() chama de novo o backend (após paywall upgrade).
///
/// Uso:
///   if (subscriptionController.has('coachChat')) { ... }
///   await subscriptionController.refresh(); // depois de assinar
class SubscriptionController extends ChangeNotifier {
  final SubscriptionRemoteDatasource _ds = SubscriptionRemoteDatasource();
  UserSubscription? _current;
  bool _loading = false;

  UserSubscription get current =>
      _current ??
      const UserSubscription(
        planId: 'freemium',
        plan: SubscriptionPlan.freemiumFallback,
      );

  bool get isPro => current.planId == 'pro';
  bool get isLoading => _loading;
  PlanFeatures get features => current.plan.features;
  PlanLimits get limits => current.plan.limits;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _current = await _ds.getMine();
    } catch (_) {
      // Mantém o cached ou fica no freemium fallback.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Helper genérico — passe a key da feature.
  bool has(String feature) {
    final f = features;
    switch (feature) {
      case 'runTracking':
        return f.runTracking;
      case 'freeRun':
        return f.freeRun;
      case 'plannedRun':
        return f.plannedRun;
      case 'generatePlan':
        return f.generatePlan;
      case 'weeklyReports':
        return f.weeklyReports;
      case 'planRevisions':
        return f.planRevisions;
      case 'coachChat':
        return f.coachChat;
      case 'coachLive':
        return f.coachLive;
      case 'coachVoiceDuringRun':
        return f.coachVoiceDuringRun;
      case 'healthZones':
        return f.healthZones;
      case 'examsOCR':
        return f.examsOCR;
      case 'wearableSync':
        return f.wearableSync;
      case 'shareWithOverlay':
        return f.shareWithOverlay;
      case 'historyExport':
        return f.historyExport;
      default:
        return false;
    }
  }
}

final subscriptionController = SubscriptionController();
