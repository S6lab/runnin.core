import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/features/admin/presentation/pages/admin_page.dart';
import 'package:runnin/features/assessment/presentation/pages/assessment_page.dart';
import 'package:runnin/features/auth/presentation/pages/login_page.dart';
import 'package:runnin/features/home/presentation/pages/home_page.dart';
import 'package:runnin/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/features/run/presentation/pages/coach_intro_page.dart';
import 'package:runnin/features/run/presentation/pages/prep_page.dart';
import 'package:runnin/features/run/presentation/pages/active_run_page.dart';
import 'package:runnin/features/run/presentation/pages/report_page.dart';
import 'package:runnin/features/training/presentation/pages/training_page.dart';
import 'package:runnin/features/training/presentation/pages/session_detail_page.dart';
import 'package:runnin/features/training/presentation/pages/week_detail_page.dart';
import 'package:runnin/features/coach/presentation/pages/coach_chat_page.dart';
import 'package:runnin/features/history/presentation/pages/benchmark_page.dart';
import 'package:runnin/features/history/presentation/pages/coach_conversation_page.dart';
import 'package:runnin/features/history/presentation/pages/history_page.dart';
import 'package:runnin/features/history/presentation/pages/run_detail_page.dart';
import 'package:runnin/features/profile/presentation/pages/account_page.dart';
import 'package:runnin/features/profile/presentation/pages/account_access_page.dart';
import 'package:runnin/features/profile/presentation/pages/health_page.dart';
import 'package:runnin/features/profile/presentation/pages/profile_page.dart';
import 'package:runnin/features/profile/presentation/pages/settings_page.dart';
import 'package:runnin/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:runnin/features/gamification/presentation/pages/gamification_page.dart';
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

    if (!loggedIn) {
      if (loc != '/onboarding' && loc != '/login') return '/onboarding';
      return null;
    }

    // Logado mas ainda não fez onboarding
    if (onboardingStatus == false && loc != '/onboarding') {
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
    GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
    GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),

    // Fluxo de corrida — RunBloc compartilhado entre prep → run → report
    GoRoute(
      path: '/assessment',
      builder: (_, state) => AssessmentPage(
        redo: state.uri.queryParameters['redo'] == '1',
      ),
    ),

    ShellRoute(
      parentNavigatorKey: _rootNavigatorKey,
      navigatorKey: _runFlowNavigatorKey,
      builder: (context, state, child) =>
          BlocProvider(create: (_) => RunBloc(), child: child),
      routes: [
        GoRoute(
          path: '/coach-intro',
          builder: (_, _) => const CoachIntroPage(),
        ),
        GoRoute(
          path: '/prep',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final session = extra?['session'] as PlanSession?;
            final week = extra?['week'] as PlanWeek?;
            final planId = extra?['planId'] as String?;
            return PrepPage(session: session, week: week, planId: planId);
          },
        ),
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
          path: '/week-detail',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final week = extra?['week'] as PlanWeek?;
            final sessions = extra?['sessions'] as List<PlanSession>?;
            final planId = extra?['planId'] as String?;
            if (week == null || sessions == null || planId == null) {
              return const Center(child: Text('Semana não encontrada'));
            }
            return WeekDetailPage(week: week, sessions: sessions, planId: planId);
          },
        ),
        GoRoute(
          path: '/session-detail',
          builder: (_, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final session = extra?['session'] as PlanSession?;
            final week = extra?['week'] as PlanWeek?;
            final planId = extra?['planId'] as String?;
            if (session == null || week == null || planId == null) {
              return const Center(child: Text('Sessão não encontrada'));
            }
            return SessionDetailPage(session: session, week: week, planId: planId);
          },
        ),
        GoRoute(path: '/coach', builder: (_, _) => const CoachChatPage()),
        GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
        GoRoute(
          path: '/run-detail',
          builder: (_, state) => RunDetailPage(runId: state.extra as String? ?? ''),
        ),
        GoRoute(
          path: '/coach-conversation',
          builder: (_, state) => CoachConversationPage(runId: state.extra as String? ?? ''),
        ),
        GoRoute(path: '/benchmark', builder: (_, _) => const BenchmarkPage()),
        GoRoute(path: '/profile', builder: (_, _) => const AccountPage()),
        GoRoute(
          path: '/profile/access',
          builder: (_, _) => const AccountAccessPage(),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, _) => const ProfilePage(initialEditing: true),
        ),
        GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
        GoRoute(path: '/gamification', builder: (_, _) => const GamificationPage()),
        GoRoute(path: '/health', builder: (_, _) => const HealthPage()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      ],
    ),
  ],
);

String _initialLocation() {
  final path = Uri.base.path;
  if (path == '/admin' || path.startsWith('/admin/')) return '/admin';
  return '/home';
}

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}
