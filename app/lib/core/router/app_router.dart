import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/features/admin/presentation/pages/admin_page.dart';
import 'package:runnin/features/auth/presentation/pages/login_page.dart';
import 'package:runnin/features/coach_intro/presentation/pages/coach_intro_page.dart';
import 'package:runnin/features/home/presentation/pages/home_page.dart';
import 'package:runnin/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/features/run/presentation/pages/prep_page.dart';
import 'package:runnin/features/run/presentation/pages/active_run_page.dart';
import 'package:runnin/features/run/presentation/pages/report_page.dart';
import 'package:runnin/features/run/presentation/pages/plan_loading_page.dart';
import 'package:runnin/features/training/presentation/pages/training_page.dart';
import 'package:runnin/features/coach/presentation/pages/coach_chat_page.dart';
import 'package:runnin/features/history/presentation/pages/history_page.dart';
import 'package:runnin/features/profile/presentation/pages/account_page.dart';
import 'package:runnin/features/profile/presentation/pages/account_access_page.dart';
import 'package:runnin/features/profile/presentation/pages/health_exams_page.dart';
import 'package:runnin/features/profile/presentation/pages/profile_page.dart';
import 'package:runnin/features/profile/presentation/pages/settings/settings_index_page.dart';
import 'package:runnin/features/profile/presentation/pages/settings/coach_settings_page.dart';
import 'package:runnin/features/profile/presentation/pages/settings/notifications_settings_page.dart';
import 'package:runnin/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:runnin/features/gamification/presentation/pages/gamification_page.dart';
import 'package:runnin/features/splash/presentation/pages/splash_page.dart';
import 'package:runnin/shared/widgets/main_layout.dart';

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

    // Allow splash to render briefly on cold start; SplashPage advances itself.
    if (loc == '/splash') return null;

    if (!loggedIn) {
      if (loc != '/onboarding' && loc != '/login') return '/onboarding';
      return null;
    }

    // Logado mas ainda não fez onboarding
    if (onboardingStatus == false &&
        loc != '/onboarding' &&
        loc != '/plan-loading') {
      return '/onboarding';
    }

    if (onboardingStatus == true &&
        loc == '/onboarding' &&
        state.uri.queryParameters['redo'] != '1') {
      return '/home';
    }

    if (loc == '/login') return '/home';
    return null;
  },
  refreshListenable: _AuthChangeNotifier(),
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
    GoRoute(path: '/plan-loading', builder: (_, _) => const PlanLoadingPage()),
    GoRoute(path: '/coach-intro', builder: (_, _) => const CoachIntroPage()),

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
        GoRoute(path: '/coach', builder: (_, _) => const CoachChatPage()),
        GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
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
          path: '/profile/edit',
          builder: (_, _) => const ProfilePage(initialEditing: true),
        ),
        GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
        GoRoute(path: '/gamification', builder: (_, _) => const GamificationPage()),
        GoRoute(path: '/profile/health', builder: (_, _) => const HealthIndexPage()),
        GoRoute(path: '/profile/health/trends', builder: (_, _) => const HealthTrendsPage()),
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
