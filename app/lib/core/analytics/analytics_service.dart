import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  FirebaseAnalytics? get _analytics =>
      kIsWeb ? FirebaseAnalytics.instance : FirebaseAnalytics.instance;

  Future<void> logEvent(String name, {Map<String, Object?>? params}) async {
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: params?.map((k, v) => MapEntry(k, v ?? '')),
      );
    } catch (e, st) {
      debugPrint('Analytics.logEvent($name) failed: $e');
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'analytics_log_event_$name',
        );
      }
    }
  }

  void recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    Map<String, Object?>? context,
  }) {
    debugPrint('[$reason] $error');
    if (kIsWeb) return;
    try {
      if (context != null) {
        for (final entry in context.entries) {
          FirebaseCrashlytics.instance
              .setCustomKey(entry.key, '${entry.value}');
        }
      }
      FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
    } catch (_) {
      // never let telemetry break the caller
    }
  }
}

final analytics = AnalyticsService.instance;
