import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/features/admin/presentation/pages/admin_page.dart';
import 'package:runnin/features/admin/presentation/pages/prompts_admin_page.dart';
import 'package:runnin/features/intro/presentation/pages/intro_page.dart';
import 'package:runnin/features/paywall/presentation/pages/paywall_page.dart';
import 'package:runnin/features/coach_live/presentation/pages/coach_live_page.dart';
import 'package:runnin/features/auth/presentation/pages/login_page.dart';
import 'package:runnin/features/coach_intro/presentation/pages/coach_intro_page.dart';
import 'package:runnin/features/home/presentation/pages/home_page.dart';
import 'package:runnin/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/features/run/presentation/pages/prep_page.dart';
import 'package:runnin/features/run/presentation/pages/active_run_page.dart';
import 'package:runnin/features/run/presentation/pages/report_page.dart';
import 'package:runnin/features/run/presentation/pages/share_page.dart';
import 'package:runnin/features/run/presentation/pages/plan_loading_page.dart';
import 'package:runnin/features/training/presentation/pages/training_page.dart';
import 'package:runnin/features/training/presentation/pages/plan_detail_page.dart';
import 'package:runnin/features/training/presentation/pages/revision_flow_page.dart';
import 'package:runnin/features/history/presentation/pages/history_page.dart';
import 'package:runnin/features/history/presentation/pages/run_detail_page.dart';
import 'package:runnin/features/history/presentation/pages/coach_conversation_replay_page.dart';
import 'package:runnin/features/profile/presentation/pages/account_page.dart';
import 'package:runnin/features/profile/presentation/pages/account_access_page.dart';
import 'package:runnin/features/profile/presentation/pages/health_exams_page.dart';
import 'package:runnin/features/profile/presentation/pages/health/devices_page.dart';
import 'package:runnin/features/profile/presentation/pages/health/health_zones_page.dart';
import 'package:runnin/features/profile/presentation/pages/profile_page.dart';
import 'package:runnin/features/profile/presentation/pages/settings/settings_index_page.dart';
import 'package:runnin/features/profile/presentation/pages/settings/coach_settings_page.dart';
import 'package:runnin/features/profile/presentation/pages/settings/notifications_settings_page.dart';
import 'package:runnin/features/profile/presentation/pages/settings/units_settings_page.dart';
import 'package:runnin/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:runnin/features/profile/presentation/pages/health/health_index_page.dart';
import 'package:runnin/features/profile/presentation/pages/health/health_trends_page.dart';
import 'package:runnin/features/gamification/presentation/pages/gamification_page.dart';
import 'package:runnin/features/splash/presentation/pages/splash_page.dart';
import 'package:runnin/shared/widgets/main_layout.dart';
import 'package:runnin/features/training/presentation/pages/weekly_report_detail_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _runFlowNavigatorKey = GlobalKey<NavigatorState>();

// Cache em memória para o status de onboarding (evita fetch a cada redirect)
bool? _onboardingDone;
const _settingsBoxName = 'runnin_settings';
const _onboardingCacheKey = 'onboarding_completed';

Box<dynamic>? _settingsBoxOrNull() {
  if (!Hive.isBoxOpen(_settingsBoxName)) return null;
  return Hive.box<dynamic>(_settingsBoxName);
}

bool? onboardingCacheStatus() {
  final cached = _onboardingDone;
  if (cached != null) return cached;

  final box = _settingsBoxOrNull();
  final persisted = box?.get(_onboardingCacheKey);
  if (persisted is bool) {
    _onboardingDone = persisted;
    return persisted;
  }
  return null;
}

void markOnboardingDone() {
  _onboardingDone = true;
  _settingsBoxOrNull()?.put(_onboardingCacheKey, true);
}

void markOnboardingPending() {
  _onboardingDone = false;
  _settingsBoxOrNull()?.put(_onboardingCacheKey, false);
}

void clearOnboardingCache() {
  _onboardingDone = null;
  _settingsBoxOrNull()?.delete(_onboardingCacheKey);
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: _initialLocation(),
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final loc = state.matchedLocation;
    final path = state.uri.path;
    final onboardingStatus = onboardingCacheStatus();

    if (loc == '/admin' || path == '/admin' || path.startsWith('/admin/')) {
      return null;
    }

    // Public routes (no auth needed). SplashPage advances itself.
    const publicRoutes = {'/splash', '/login'};
    if (publicRoutes.contains(loc)) {
      // Logado + onboarding concluído cai em /login → manda direto pra home.
      // Logado mid-onboarding fica em /login normalmente (o login_page
      // navega pra /onboarding após autenticar).
      if (loggedIn && loc == '/login' && onboardingStatus == true) {
        return '/home';
      }
      return null;
    }

    // Daqui em diante, rotas privadas: precisa estar logado.
    if (!loggedIn) {
      // Logout ou acesso direto sem auth → manda pra login (não pra onboarding).
      return '/login';
    }

    // Logado mas ainda não fez onboarding → assessment
    if (onboardingStatus == false &&
        loc != '/onboarding' &&
        loc != '/plan-loading' &&
        loc != '/paywall') {
      return '/onboarding';
    }

    if (onboardingStatus == true &&
        loc == '/onboarding' &&
        state.uri.queryParameters['redo'] != '1') {
      return '/home';
    }

    return null;
  },
  refreshListenable: _AuthChangeNotifier(),
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
    GoRoute(path: '/admin/prompts', builder: (_, _) => const PromptsAdminPage()),
    GoRoute(path: '/intro', builder: (_, _) => const IntroPage()),
    GoRoute(
      path: '/coach-live',
      builder: (_, state) => CoachLivePage(
        runId: state.uri.queryParameters['runId'],
      ),
    ),
    GoRoute(
      path: '/paywall',
      builder: (_, state) => PaywallPage(
        nextRoute: state.uri.queryParameters['next'] ?? '/home',
      ),
    ),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
    GoRoute(path: '/plan-loading', builder: (_, _) => const PlanLoadingPage()),
    GoRoute(path: '/coach-intro', builder: (_, _) => const CoachIntroPage()),
    GoRoute(
      path: '/share',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return SharePage(runId: extra['runId'] as String? ?? '');
      },
    ),

    // Fluxo de corrida — RunBloc compartilhado entre prep → run → report
    ShellRoute(
      parentNavigatorKey: _rootNavigatorKey,
      navigatorKey: _runFlowNavigatorKey,
      builder: (context, state, child) =>
          BlocProvider(create: (_) => RunBloc(), child: child),
      routes: [
        GoRoute(path: '/prep', builder: (_, _) => const PrepPage()),
        GoRoute(
          path: '/run',
          builder: (_, state) =>
              ActiveRunPage(runId: state.extra as String? ?? ''),
        ),
        GoRoute(
          path: '/report',
          builder: (_, state) =>
              ReportPage(runId: state.extra as String? ?? ''),
        ),
      ],
    ),

    // Shell com bottom nav
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(path: '/training', builder: (_, _) => const TrainingPage()),
        GoRoute(
          path: '/training/plan-detail',
          builder: (_, _) => const PlanDetailPage(),
        ),
        GoRoute(
          path: '/training/report/:weekStart',
          builder: (_, state) => WeeklyReportDetailPage(
            weekStart: state.pathParameters['weekStart']!,
          ),
        ),
        GoRoute(
          path: '/training/revise',
          builder: (_, state) => RevisionFlowPage(
            planId: state.uri.queryParameters['planId'] ?? '',
          ),
        ),
        GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
        GoRoute(
          path: '/history/run/:runId',
          builder: (_, state) =>
              RunDetailPage(runId: state.pathParameters['runId']!),
        ),
        GoRoute(
          path: '/history/run/:runId/conversa',
          builder: (_, state) =>
              CoachConversationReplayPage(runId: state.pathParameters['runId']!),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const AccountPage()),
        GoRoute(
          path: '/profile/access',
          builder: (_, _) => const AccountAccessPage(),
        ),
        GoRoute(
          path: '/profile/health/exams',
          builder: (_, _) => const HealthExamsPage(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, _) => const ProfilePage(initialEditing: true),
        ),
        GoRoute(
          path: '/profile/settings',
          builder: (_, _) => const SettingsIndexPage(),
        ),
        GoRoute(
          path: '/profile/settings/coach',
          builder: (_, _) => const CoachSettingsPage(),
        ),
        GoRoute(
          path: '/profile/settings/notifications',
          builder: (_, _) => const NotificationsSettingsPage(),
        ),
        GoRoute(
          path: '/profile/settings/units',
          builder: (_, _) => const UnitsSettingsPage(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, _) => const ProfilePage(initialEditing: true),
        ),
        GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
        GoRoute(path: '/gamification', builder: (_, _) => const GamificationPage()),
        GoRoute(path: '/profile/health', builder: (_, _) => const HealthIndexPage()),
        GoRoute(
          path: '/profile/health/devices',
          builder: (_, _) => const HealthDevicesPage(),
        ),
        GoRoute(
          path: '/profile/health/trends',
          builder: (_, _) => const HealthTrendsPage(),
        ),
        GoRoute(
          path: '/profile/health/zones',
          builder: (_, _) => const HealthZonesPage(),
        ),
      ],
    ),
  ],
);

String _initialLocation() {
  final path = Uri.base.path;
  if (path == '/admin' || path.startsWith('/admin/')) return '/admin';
  // Deep links (anything beyond '/') skip the splash and go to that path.
  if (path.length > 1) return path;
  return '/splash';
}

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}
