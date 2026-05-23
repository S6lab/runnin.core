import 'package:runnin/features/notifications/domain/entities/app_notification.dart';

/// Resolve a rota de deep-link para uma notificação. Prioridade:
///   1. `ctaRoute` explícito do server (se preenchido, é override)
///   2. mapa por `type` (fallback determinístico no client)
///   3. `/notifications` (último recurso — abre a própria lista)
///
/// Mantém a UI tappable mesmo quando o server não preenche `ctaRoute`
/// (caso dos insights diários: hidratação, sono, bpm, etc).
String routeForNotification(AppNotification n) {
  final cta = n.ctaRoute;
  if (cta != null && cta.isNotEmpty) return cta;

  switch (n.type) {
    // Coach daily insights — 7 cards de /ensure-daily
    case 'melhor_horario':
      return '/training';
    case 'preparo_nutricional':
      return '/training';
    case 'hidratacao':
      return '/profile/health';
    case 'checklist_pre_easy_run':
      return '/prep';
    case 'sono_performance':
      return '/profile/health/devices';
    case 'bpm_real':
      return '/profile/health/zones';
    case 'fechamento_mensal':
      return '/profile/health/trends';

    // Eventos de plano
    case 'plan_ready':
      return '/training';
    case 'plan_proposal':
      final planId = n.data?['planId'] as String?;
      return planId != null && planId.isNotEmpty
          ? '/training/revise?planId=$planId'
          : '/training';

    // Coach async
    case 'coach_message':
      return '/coach-live';

    default:
      return '/notifications';
  }
}
