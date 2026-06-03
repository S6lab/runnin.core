import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:runnin/core/analytics/analytics_service.dart';

/// Facade pra logging estruturado. DRY: substitui o uso espalhado de
/// `debugPrint` + `analytics.recordError` em catches.
///
/// Em debug: imprime no console com prefixo de nível.
/// Em release: encaminha pro Crashlytics via `AnalyticsService.recordError`.
///
/// O `reason` é dot.notation curta (ex.: `home.load_failed`,
/// `bpm.event_parse_failed`) — vira o título da issue no Crashlytics.
/// `context` aparece como custom keys.
///
/// Uso:
///   try { ... }
///   catch (e, st) { Logger.error('home.load_failed', e, st, context: {'step': 'getMe'}); }
class Logger {
  Logger._();

  static void error(
    String reason,
    Object error, [
    StackTrace? stack,
    Map<String, Object?>? context,
  ]) {
    final ctxStr = context == null || context.isEmpty ? '' : ' $context';
    debugPrint('[ERROR][$reason] $error$ctxStr');
    analytics.recordError(error, stack, reason: reason, context: context);
  }

  static void warn(String message, {Map<String, Object?>? context}) {
    final ctxStr = context == null || context.isEmpty ? '' : ' $context';
    debugPrint('[WARN][$message]$ctxStr');
  }

  static void info(String message, {Map<String, Object?>? context}) {
    if (!kDebugMode) return; // silencioso em release
    final ctxStr = context == null || context.isEmpty ? '' : ' $context';
    debugPrint('[INFO][$message]$ctxStr');
  }
}
