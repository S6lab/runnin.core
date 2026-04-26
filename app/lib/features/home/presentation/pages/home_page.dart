import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/home/domain/use_cases/get_home_data_use_case.dart';
import 'package:runnin/features/home/presentation/cubit/home_cubit.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit()..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  @override
  void initState() {
    super.initState();
    final cachedStatus = onboardingCacheStatus();
    if (cachedStatus != true) {
      _checkOnboarding(cachedStatus);
    }
  }

  Future<void> _checkOnboarding(bool? cachedStatus) async {
    if (cachedStatus == false) {
      markOnboardingPending();
      if (mounted) context.go('/onboarding');
      return;
    }

    try {
      final profile = await UserRemoteDatasource().getMe();
      if (profile == null || !profile.onboarded) {
        markOnboardingPending();
        if (mounted) context.go('/onboarding');
      } else {
        markOnboardingDone();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HomeHeader(),
                  const SizedBox(height: 20),
                  if (state is HomeLoading) ...[
                    const _LoadingCard(),
                    const SizedBox(height: 12),
                    const _LoadingCard(),
                  ] else if (state is HomeError) ...[
                    _ErrorCard(
                      message: state.message,
                      onRetry: () => context.read<HomeCubit>().load(),
                    ),
                  ] else if (state is HomeLoaded) ...[
                    _IniciarSessaoButton(data: state.data),
                    const SizedBox(height: 20),
                    _CoachNotifications(data: state.data),
                    const SizedBox(height: 20),
                    _SemanaSection(data: state.data),
                    const SizedBox(height: 20),
                    _PerformanceSection(data: state.data),
                    const SizedBox(height: 20),
                    _StatusCorporalSection(data: state.data),
                    const SizedBox(height: 20),
                    _UltimaCorrida(run: state.data.latestRun),
                  ] else ...[
                    const _LoadingCard(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final user = FirebaseAuth.instance.currentUser;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'RUNIN',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.03,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: palette.primary),
              child: Text(
                '.AI',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.05,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            InkWell(
              onTap: () => context.push('/dashboard'),
              child: Icon(
                Icons.bar_chart_outlined,
                size: 22,
                color: palette.muted,
              ),
            ),
            const SizedBox(width: 14),
            InkWell(
              onTap: () => context.push('/profile'),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: palette.border),
                  color: palette.surface,
                  shape: BoxShape.circle,
                  image: user?.photoURL != null
                      ? DecorationImage(
                          image: NetworkImage(user!.photoURL!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: user?.photoURL == null
                    ? Text(
                        _initial(user),
                        style: TextStyle(
                          color: palette.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _initial(User? user) {
    final name = user?.displayName?.trim();
    if (name == null || name.isEmpty) return 'R';
    return name[0].toUpperCase();
  }
}

// ─── Iniciar Sessão ───────────────────────────────────────────────────────────

class _IniciarSessaoButton extends StatelessWidget {
  final HomeData data;
  const _IniciarSessaoButton({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.plan == null) {
      return AppPanel(
        color: context.runninPalette.surfaceAlt,
        borderColor: context.runninPalette.primary.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTag(label: 'PLANO', color: context.runninPalette.primary),
            const SizedBox(height: 14),
            Text(
              'Seu app ja esta pronto para gerar o primeiro bloco de treino.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Complete o setup no modulo de treino para liberar a sessao do dia.',
              style: TextStyle(
                color: context.runninPalette.text.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/training'),
                child: const Text('GERAR MEU PLANO'),
              ),
            ),
          ],
        ),
      );
    }

    if (data.plan!.isGenerating) {
      return AppPanel(
        child: Column(
          children: [
            CircularProgressIndicator(
              color: context.runninPalette.primary,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Gerando seu plano...',
              style: TextStyle(color: context.runninPalette.muted),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => context.push('/prep'),
        icon: const Icon(Icons.play_arrow, size: 20),
        label: Text(
          data.todaySession != null
              ? 'INICIAR SESSAO'
              : 'INICIAR CORRIDA LIVRE',
          style: const TextStyle(
            letterSpacing: 0.1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ─── Coach Notificações ───────────────────────────────────────────────────────

class _CoachNotifications extends StatelessWidget {
  final HomeData data;
  const _CoachNotifications({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final profile = data.profile;
    final items = <_CoachItem>[
      _CoachItem(
        icon: Icons.flag_outlined,
        label: 'OBJETIVO ATUAL',
        time: profile?.level.toUpperCase() ?? 'PERFIL',
        body: profile != null && profile.goal.trim().isNotEmpty
            ? 'Seu plano esta alinhado ao objetivo "${profile.goal}" e a sua frequencia de ${profile.frequency} treinos por semana.'
            : 'Preencha seu objetivo e frequencia para personalizar as recomendacoes do coach.',
        accent: palette.primary,
        ctaLabel: profile == null || profile.goal.trim().isEmpty
            ? 'COMPLETAR PERFIL'
            : null,
        onTap: profile == null || profile.goal.trim().isEmpty
            ? () => context.push('/profile/edit')
            : null,
      ),
      _CoachItem(
        icon: Icons.directions_run_outlined,
        label: 'SESSAO DE HOJE',
        time: data.todaySession != null ? 'PLANO' : 'LIVRE',
        body: data.todaySession != null
            ? 'Hoje voce tem ${data.todaySession!.type} com ${_formatKm(data.todaySession!.distanceKm)} e foco em ${_sessionGoal(data.todaySession!)}.'
            : 'Ainda nao existe sessao planejada para hoje. Voce pode iniciar uma corrida livre ou revisar seu plano.',
        accent: palette.secondary,
        ctaLabel: data.todaySession == null ? 'ABRIR TREINO' : null,
        onTap: data.todaySession == null
            ? () => context.push('/training')
            : null,
      ),
      _CoachItem(
        icon: Icons.monitor_heart_outlined,
        label: 'DADOS CONECTADOS',
        time: profile?.hasWearable == true ? 'WEARABLE' : 'PENDENTE',
        body: profile?.hasWearable == true
            ? 'Seu perfil indica wearable conectado. Assim que entrarem dados de BPM e sono, o coach passa a usar isso nas recomendacoes.'
            : 'Sem wearable conectado, o coach ainda personaliza por perfil, plano e corridas, mas nao consegue estimar sono ou prontidao fisiologica.',
        accent: profile?.hasWearable == true ? palette.primary : palette.muted,
        ctaLabel: profile?.hasWearable == true ? null : 'ATUALIZAR PERFIL',
        onTap: profile?.hasWearable == true
            ? null
            : () => context.push('/profile/edit'),
      ),
      _CoachItem(
        icon: Icons.person_outline,
        label: 'BASE DO PERFIL',
        time: _profileCompletenessLabel(profile),
        body: _buildProfileContext(profile),
        accent: palette.secondary,
        ctaLabel: _isBodyProfileComplete(profile) ? null : 'PREENCHER DADOS',
        onTap: _isBodyProfileComplete(profile)
            ? null
            : () => context.push('/profile/edit'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'COACH',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.02,
                      ),
                    ),
                    TextSpan(
                      text: '.AI',
                      style: TextStyle(
                        color: palette.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppTag(label: '${items.length}', color: palette.primary),
            const SizedBox(width: 8),
            Text(
              'LIMPAR',
              style: TextStyle(
                color: palette.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _CoachCard(item: item)),
      ],
    );
  }

  static bool _isBodyProfileComplete(UserProfile? profile) {
    if (profile == null) return false;
    return (profile.birthDate?.trim().isNotEmpty ?? false) &&
        (profile.weight?.trim().isNotEmpty ?? false) &&
        (profile.height?.trim().isNotEmpty ?? false);
  }

  static String _profileCompletenessLabel(UserProfile? profile) {
    if (_isBodyProfileComplete(profile)) return 'COMPLETO';
    return 'INCOMPLETO';
  }

  static String _buildProfileContext(UserProfile? profile) {
    if (profile == null) {
      return 'Seu perfil ainda nao foi carregado. Entre no perfil para revisar seus dados.';
    }

    final parts = <String>[];
    if (profile.birthDate?.trim().isNotEmpty ?? false) {
      parts.add('data de nascimento informada');
    }
    if (profile.weight?.trim().isNotEmpty ?? false) {
      parts.add('peso ${profile.weight}');
    }
    if (profile.height?.trim().isNotEmpty ?? false) {
      parts.add('altura ${profile.height}');
    }

    if (parts.isEmpty) {
      return 'Faltam idade, peso e altura para destravar analises corporais mais personalizadas.';
    }

    return 'O coach esta usando ${parts.join(', ')} junto com seu nivel e objetivo para personalizar o app.';
  }
}

class _CoachItem {
  final IconData icon;
  final String label;
  final String time;
  final String body;
  final Color accent;
  final String? ctaLabel;
  final VoidCallback? onTap;

  const _CoachItem({
    required this.icon,
    required this.label,
    required this.time,
    required this.body,
    required this.accent,
    this.ctaLabel,
    this.onTap,
  });
}

class _CoachCard extends StatelessWidget {
  final _CoachItem item;
  const _CoachCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 18, color: item.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                    ),
                    Text(
                      item.time,
                      style: TextStyle(
                        color: item.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                if (item.ctaLabel != null && item.onTap != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: item.onTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(item.ctaLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Semana ───────────────────────────────────────────────────────────────────

class _SemanaSection extends StatelessWidget {
  final HomeData data;
  const _SemanaSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final weekNum = _isoWeekNumber(now);
    final monthAbbr = _monthAbbr(monday.month);
    final volumePct = data.plannedSessions == 0
        ? 0.0
        : (data.completedSessions / data.plannedSessions).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SEMANA',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.02,
              ),
            ),
            const SizedBox(width: 8),
            AppTag(
              label: '${data.completedSessions}/${data.plannedSessions} FEITAS',
              color: palette.primary,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Sem $weekNum · $monthAbbr ${monday.day}-${sunday.day} · ${data.completedSessions}/${data.plannedSessions} sessoes · ${(volumePct * 100).round()}% volume',
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _WeekGrid(weekDays: data.weekDays),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'VOLUME',
              style: TextStyle(
                color: palette.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.08,
              ),
            ),
            const Spacer(),
            Text(
              '${data.weeklyDistanceKm.toStringAsFixed(1)} / ${(data.plannedSessions * 5.0).toStringAsFixed(0)} km',
              style: TextStyle(
                color: palette.text,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRect(
          child: SizedBox(
            height: 3,
            child: Row(
              children: [
                Flexible(
                  flex: (volumePct * 100).round(),
                  child: Container(color: palette.primary),
                ),
                Flexible(
                  flex: 100 - (volumePct * 100).round(),
                  child: Container(color: palette.border),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _isoWeekNumber(DateTime date) {
    final doy = int.parse(
      '${date.difference(DateTime(date.year, 1, 1)).inDays + 1}',
    );
    final dow = date.weekday;
    return ((doy - dow + 10) / 7).floor();
  }

  String _monthAbbr(int month) {
    const abbrs = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return abbrs[month];
  }
}

class _WeekGrid extends StatelessWidget {
  final List<WeekDayData> weekDays;
  const _WeekGrid({required this.weekDays});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      children: weekDays.map((day) {
        final isRest = day.session == null;
        final distLabel = day.session == null
            ? 'DESC'
            : _fmtDist(day.session!.distanceKm);

        return Expanded(
          child: Container(
            height: 102,
            margin: EdgeInsets.only(right: day.dayOfWeek == 7 ? 0 : 4),
            decoration: BoxDecoration(
              color: day.isToday ? palette.surfaceAlt : palette.surface,
              border: Border.all(
                color: day.isToday
                    ? palette.primary.withValues(alpha: 0.4)
                    : palette.border,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.shortName,
                  style: TextStyle(
                    color: day.isDone
                        ? palette.primary
                        : day.isToday
                        ? palette.secondary
                        : palette.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.06,
                  ),
                ),
                const SizedBox(height: 6),
                if (day.isDone)
                  Icon(Icons.check, size: 14, color: palette.primary)
                else if (isRest)
                  Text(
                    'OFF',
                    style: TextStyle(
                      color: palette.border,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  Text(
                    day.session!.type.substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      color: day.isToday ? palette.text : palette.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  distLabel,
                  style: TextStyle(
                    color: isRest ? palette.border : palette.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (day.session?.targetPace != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    day.session!.targetPace!,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (day.isToday) ...[
                  const SizedBox(height: 4),
                  Text(
                    'HOJE',
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _fmtDist(double km) {
    if (km >= 1) {
      final dec = km == km.truncateToDouble() ? 0 : 1;
      return '${km.toStringAsFixed(dec)}K';
    }
    return '${(km * 1000).toStringAsFixed(0)}m';
  }
}

// ─── Performance ─────────────────────────────────────────────────────────────

class _PerformanceSection extends StatelessWidget {
  final HomeData data;
  const _PerformanceSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final runs = data.completedRuns;
    final run = data.latestRun;
    final avgPace = _averagePace(runs);
    final weeklyGoalKm = _plannedWeeklyDistance(data);
    final weeklyCompletion = weeklyGoalKm <= 0
        ? null
        : (data.weeklyDistanceKm / weeklyGoalKm).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'PERFORMANCE',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.02,
                ),
              ),
              TextSpan(
                text: ' ᴬᴵ',
                style: TextStyle(color: palette.primary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PACE TREND',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        avgPace ?? '--',
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.02,
                        ),
                      ),
                      Text(
                        avgPace != null
                            ? '/km · media das corridas'
                            : 'sem corridas suficientes',
                        style: TextStyle(color: palette.muted, fontSize: 9),
                      ),
                      const Spacer(),
                      if (avgPace == null)
                        TextButton(
                          onPressed: () => context.push('/prep'),
                          child: const Text('FAZER PRIMEIRA CORRIDA'),
                        )
                      else
                        Container(height: 3, color: palette.border),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARDIACO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        run?.avgBpm != null ? '${run!.avgBpm}' : '--',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        run?.avgBpm != null
                            ? 'bpm medio na ultima corrida'
                            : 'sem BPM registrado',
                        style: TextStyle(color: palette.muted, fontSize: 9),
                      ),
                      const Spacer(),
                      if (run?.avgBpm != null) ...[
                        Text(
                          'ZONA ESTIMADA',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${run!.avgBpm}',
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _ZoneBars(avgBpm: run.avgBpm!),
                      ],
                      if (run?.avgBpm == null)
                        TextButton(
                          onPressed: () => context.push('/profile/edit'),
                          child: const Text('ATIVAR DADOS DE BPM'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppPanel(
                  color: palette.primary,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BENCHMARK',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weeklyCompletion == null
                            ? 'SEM BASE'
                            : '${(weeklyCompletion * 100).round()}%',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.02,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        weeklyCompletion == null
                            ? 'faltam km planejados para comparar'
                            : 'do volume previsto nesta semana',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                      if (weeklyCompletion == null)
                        TextButton(
                          onPressed: () => context.push('/training'),
                          child: const Text('VER PLANO'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STREAK',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${data.streakDays}',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.02,
                        ),
                      ),
                      Text(
                        'dias',
                        style: TextStyle(color: palette.muted, fontSize: 11),
                      ),
                      const Spacer(),
                      _MonthStats(data: data),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZoneBars extends StatelessWidget {
  final int avgBpm;
  const _ZoneBars({required this.avgBpm});

  @override
  Widget build(BuildContext context) {
    final zones = <Color>[
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.yellow.shade600,
      Colors.orange.shade500,
      Colors.red.shade500,
    ];
    final zone = avgBpm < 120
        ? 0
        : avgBpm < 140
        ? 1
        : avgBpm < 160
        ? 2
        : avgBpm < 175
        ? 3
        : 4;

    return Row(
      children: List.generate(5, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 4 ? 2 : 0),
            height: 5,
            color: i <= zone ? zones[i] : zones[i].withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}

class _MonthStats extends StatelessWidget {
  final HomeData data;
  const _MonthStats({required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final now = DateTime.now();
    final monthNames = [
      '',
      'JANEIRO',
      'FEVEREIRO',
      'MARCO',
      'ABRIL',
      'MAIO',
      'JUNHO',
      'JULHO',
      'AGOSTO',
      'SETEMBRO',
      'OUTUBRO',
      'NOVEMBRO',
      'DEZEMBRO',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthNames[now.month],
          style: TextStyle(
            color: palette.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.06,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('KM', style: TextStyle(color: palette.muted, fontSize: 9)),
            Text(
              data.weeklyDistanceKm.toStringAsFixed(1),
              style: TextStyle(
                color: palette.text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Status Corporal ──────────────────────────────────────────────────────────

class _StatusCorporalSection extends StatefulWidget {
  final HomeData data;
  const _StatusCorporalSection({required this.data});

  @override
  State<_StatusCorporalSection> createState() => _StatusCorporalSectionState();
}

class _StatusCorporalSectionState extends State<_StatusCorporalSection> {
  double? _hydrationLoggedL;

  @override
  void initState() {
    super.initState();
    _reloadHydration();
  }

  void _reloadHydration() {
    _hydrationLoggedL = _hydrationIntakeLiters();
  }

  Future<void> _openHydrationSheet({required double goalLiters}) async {
    final currentLiters = _hydrationLoggedL ?? 0;
    final updatedLiters = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HydrationUpdateSheet(
        initialLiters: currentLiters,
        goalLiters: goalLiters,
      ),
    );
    if (updatedLiters == null) return;

    await _saveHydrationIntakeLiters(updatedLiters);
    if (!mounted) return;
    setState(() {
      _hydrationLoggedL = updatedLiters;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final profile = widget.data.profile;
    final bmi = _calculateBmi(profile);
    final hasBodyData = bmi != null;
    final readinessScore = hasBodyData
        ? _readinessScore(widget.data, bmi)
        : null;
    final hydrationGoalL = _hydrationGoalLiters(profile);
    final hydrationLoggedL = _hydrationLoggedL;
    final hydrationPct = hydrationGoalL == null || hydrationLoggedL == null
        ? null
        : (hydrationLoggedL / hydrationGoalL).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'STATUS CORPORAL',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.02,
                ),
              ),
              TextSpan(
                text: ' ᴬᴵ',
                style: TextStyle(color: palette.primary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRONTIDAO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            readinessScore?.toString() ?? '--',
                            style: TextStyle(
                              color: palette.secondary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            ' /100',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        hasBodyData
                            ? _readinessLabel(readinessScore!)
                            : 'Preencha peso, altura e idade para destravar',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                      const Spacer(),
                      if (hasBodyData)
                        ClipRect(
                          child: SizedBox(
                            height: 3,
                            child: Row(
                              children: [
                                Flexible(
                                  flex: readinessScore!,
                                  child: Container(color: palette.secondary),
                                ),
                                Flexible(
                                  flex: 100 - readinessScore,
                                  child: Container(color: palette.border),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: () => context.push('/profile/edit'),
                          child: const Text('PREENCHER DADOS'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SONO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile?.hasWearable == true ? 'AGUARDANDO' : '--',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        profile?.hasWearable == true
                            ? 'Conecte a origem de sono para sincronizar'
                            : 'Sem wearable conectado',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/profile/edit'),
                        child: Text(
                          profile?.hasWearable == true
                              ? 'REVISAR PERFIL'
                              : 'ATUALIZAR PERFIL',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CARGA MUSCULAR',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _muscleLoadLabel(widget.data),
                        style: TextStyle(
                          color: palette.secondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Baseado na ultima corrida e no volume da semana',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _CargaChip(
                            label: 'BAIXA',
                            active: _muscleLoadLabel(widget.data) == 'BAIXA',
                          ),
                          const SizedBox(width: 4),
                          _CargaChip(
                            label: 'MEDIA',
                            active: _muscleLoadLabel(widget.data) == 'MEDIA',
                          ),
                          const SizedBox(width: 4),
                          _CargaChip(
                            label: 'ALTA',
                            active: _muscleLoadLabel(widget.data) == 'ALTA',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HIDRATACAO',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            hydrationLoggedL == null
                                ? '--'
                                : '${hydrationLoggedL.toStringAsFixed(1)}L',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            hydrationGoalL == null
                                ? ''
                                : ' /${hydrationGoalL.toStringAsFixed(1)}L',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        hydrationGoalL == null
                            ? 'Informe peso para calcular sua meta diaria'
                            : hydrationLoggedL == null
                            ? 'Sem ingestao de agua registrada no app'
                            : '${(hydrationPct! * 100).round()}% da meta diaria registrada',
                        style: TextStyle(color: palette.muted, fontSize: 10),
                      ),
                      const Spacer(),
                      if (hydrationPct != null)
                        ClipRect(
                          child: SizedBox(
                            height: 3,
                            child: Row(
                              children: [
                                Flexible(
                                  flex: (hydrationPct * 100).round(),
                                  child: Container(color: palette.primary),
                                ),
                                Flexible(
                                  flex: 100 - (hydrationPct * 100).round(),
                                  child: Container(color: palette.border),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: hydrationGoalL == null
                            ? () => context.push('/profile/edit')
                            : () => _openHydrationSheet(
                                goalLiters: hydrationGoalL,
                              ),
                        child: Text(
                          hydrationGoalL == null
                              ? 'INFORMAR PESO'
                              : hydrationLoggedL == null
                              ? 'REGISTRAR AGUA'
                              : 'ATUALIZAR AGUA',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HydrationUpdateSheet extends StatefulWidget {
  final double initialLiters;
  final double goalLiters;

  const _HydrationUpdateSheet({
    required this.initialLiters,
    required this.goalLiters,
  });

  @override
  State<_HydrationUpdateSheet> createState() => _HydrationUpdateSheetState();
}

class _HydrationUpdateSheetState extends State<_HydrationUpdateSheet> {
  static const List<int> _quickMlSteps = [200, 300, 500];
  static const double _deltaLiters = 0.1;
  late double _currentLiters;

  @override
  void initState() {
    super.initState();
    _currentLiters = widget.initialLiters;
  }

  void _changeBy(double liters) {
    setState(() {
      final next = _currentLiters + liters;
      _currentLiters = next < 0 ? 0 : next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final pct = (_currentLiters / widget.goalLiters).clamp(0.0, 2.0);
    final overGoal = _currentLiters > widget.goalLiters;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.background,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'HIDRATACAO DO DIA',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${_currentLiters.toStringAsFixed(1)}L de ${widget.goalLiters.toStringAsFixed(1)}L',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pct > 1 ? 1 : pct,
                  minHeight: 8,
                  backgroundColor: palette.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overGoal ? palette.secondary : palette.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _changeBy(-_deltaLiters),
                      icon: const Icon(Icons.remove),
                      label: const Text('-100ML'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _changeBy(_deltaLiters),
                      icon: const Icon(Icons.add),
                      label: const Text('+100ML'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickMlSteps
                    .map(
                      (ml) => ActionChip(
                        label: Text('+$ml ML'),
                        onPressed: () => _changeBy(ml / 1000),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_currentLiters),
                  child: const Text('SALVAR CONSUMO'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentLiters = 0),
                child: const Text('ZERAR HOJE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CargaChip extends StatelessWidget {
  final String label;
  final bool active;
  const _CargaChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? palette.secondary.withValues(alpha: 0.15)
              : palette.surface,
          border: Border.all(
            color: active ? palette.secondary : palette.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? palette.secondary : palette.muted,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ─── Última Corrida ───────────────────────────────────────────────────────────

class _UltimaCorrida extends StatelessWidget {
  final Run? run;
  const _UltimaCorrida({required this.run});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'ULTIMA CORRIDA',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.02,
                ),
              ),
              TextSpan(
                text: ' ᴬᴵ',
                style: TextStyle(color: palette.primary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (run == null)
          AppPanel(
            child: Text(
              'Nenhuma corrida concluida ainda. Assim que voce terminar a primeira, este painel mostrara pace, BPM e XP.',
              style: TextStyle(color: palette.muted, height: 1.5),
            ),
          )
        else
          _RunCard(run: run!),
      ],
    );
  }
}

String _formatKm(double km) {
  final dec = km == km.truncateToDouble() ? 0 : 1;
  return '${km.toStringAsFixed(dec)} km';
}

String _sessionGoal(PlanSession session) {
  final type = session.type.toLowerCase();
  if (type.contains('interval')) {
    return 'estimulo de velocidade';
  }
  if (type.contains('tempo')) {
    return 'sustentar ritmo controlado';
  }
  if (type.contains('long')) {
    return 'resistencia aerobia';
  }
  return 'consistencia e base aerobia';
}

String? _averagePace(List<Run> runs) {
  final validRuns = runs
      .where((run) => run.distanceM > 0 && run.durationS > 0)
      .toList();
  if (validRuns.length < 2) {
    return validRuns.isEmpty ? null : validRuns.first.avgPace;
  }

  final totalDistanceKm = validRuns.fold<double>(
    0,
    (sum, run) => sum + (run.distanceM / 1000),
  );
  final totalDurationS = validRuns.fold<int>(
    0,
    (sum, run) => sum + run.durationS,
  );
  if (totalDistanceKm <= 0) return null;
  final secPerKm = totalDurationS / totalDistanceKm;
  final min = (secPerKm ~/ 60).toInt();
  final sec = (secPerKm % 60).round();
  return '$min:${sec.toString().padLeft(2, '0')}';
}

double _plannedWeeklyDistance(HomeData data) {
  return data.weekDays.fold<double>(
    0,
    (sum, day) => sum + (day.session?.distanceKm ?? 0),
  );
}

double? _parseDouble(String? raw) {
  if (raw == null) return null;
  final normalized = raw
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(normalized);
}

double? _calculateBmi(UserProfile? profile) {
  final weightKg = _parseDouble(profile?.weight);
  final heightCm = _parseDouble(profile?.height);
  if (weightKg == null || heightCm == null || heightCm <= 0) return null;
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

int _readinessScore(HomeData data, double bmi) {
  final latest = data.latestRun;
  var score = 55;
  if (data.todaySession != null) score += 10;
  if (data.streakDays > 0 && data.streakDays <= 4) score += 8;
  if (data.weeklyDistanceKm > 0) score += 8;
  if (latest?.avgBpm != null && latest!.avgBpm! < 165) score += 8;
  if (bmi >= 18.5 && bmi < 30) score += 6;
  return score.clamp(0, 100);
}

String _readinessLabel(int score) {
  if (score >= 75) return 'Base minima para treinar hoje';
  if (score >= 60) return 'Treino leve ou moderado recomendado';
  return 'Poucos dados ou recuperacao em observacao';
}

String _muscleLoadLabel(HomeData data) {
  final latestDistance = (data.latestRun?.distanceM ?? 0) / 1000;
  if (latestDistance >= 12 || data.weeklyDistanceKm >= 30) return 'ALTA';
  if (latestDistance >= 6 || data.weeklyDistanceKm >= 15) return 'MEDIA';
  return 'BAIXA';
}

double? _hydrationGoalLiters(UserProfile? profile) {
  final weightKg = _parseDouble(profile?.weight);
  if (weightKg == null) return null;
  return ((weightKg * 35) / 1000);
}

const _settingsBoxName = 'runnin_settings';
const _hydrationKeyPrefix = 'hydration_ml_';

String _hydrationDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$_hydrationKeyPrefix$year$month$day';
}

Box<dynamic>? _settingsBoxOrNull() {
  if (!Hive.isBoxOpen(_settingsBoxName)) return null;
  return Hive.box<dynamic>(_settingsBoxName);
}

double? _hydrationIntakeLiters() {
  final value = _settingsBoxOrNull()?.get(_hydrationDateKey(DateTime.now()));
  if (value is int) return value / 1000;
  if (value is double) return value / 1000;
  return null;
}

Future<void> _saveHydrationIntakeLiters(double liters) async {
  final box = _settingsBoxOrNull();
  if (box == null) return;

  final hydrationMl = (liters * 1000).round();
  await box.put(
    _hydrationDateKey(DateTime.now()),
    hydrationMl < 0 ? 0 : hydrationMl,
  );
}

class _RunCard extends StatelessWidget {
  final Run run;
  const _RunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final createdAt = DateTime.tryParse(run.createdAt);
    final dateLabel = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')} · ${run.type.toUpperCase()}'
        : run.type.toUpperCase();
    final distKm = (run.distanceM / 1000).toStringAsFixed(1);
    final duration = _fmtDuration(run.durationS);

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  color: palette.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'DURACAO',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.08,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${distKm}K',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.03,
                  height: 1,
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  color: palette.secondary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _RunMetric(
                label: 'PACE',
                sub: '/km',
                value: run.avgPace ?? '--',
                accent: palette.secondary,
              ),
              const SizedBox(width: 8),
              _RunMetric(
                label: 'BPM',
                sub: 'avg',
                value: run.avgBpm?.toString() ?? '--',
                accent: palette.primary,
              ),
              const SizedBox(width: 8),
              _RunMetric(
                label: 'XP',
                sub: 'pts',
                value: run.xpEarned != null ? '+${run.xpEarned}' : '--',
                accent: palette.primary,
              ),
              const SizedBox(width: 8),
              _RunMetric(
                label: 'STREAK',
                sub: 'dias',
                value: run.status == 'completed' ? '1+' : '--',
                accent: palette.text,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: palette.primary, width: 3),
              ),
            ),
            child: Text(
              'Resumo real da corrida concluida. O relatorio tecnico completo fica na aba de feedback do treino.',
              style: TextStyle(
                color: palette.text.withValues(alpha: 0.8),
                height: 1.5,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/history'),
                  child: const Text('VER DETALHES'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('COMPARTILHAR →'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDuration(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _RunMetric extends StatelessWidget {
  final String label;
  final String sub;
  final String value;
  final Color accent;
  const _RunMetric({
    required this.label,
    required this.sub,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(sub, style: TextStyle(color: palette.muted, fontSize: 9)),
        ],
      ),
    );
  }
}

// ─── Loading / Error ──────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: 160,
        child: Center(
          child: CircularProgressIndicator(
            color: palette.primary,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: palette.muted)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('TENTAR NOVAMENTE')),
        ],
      ),
    );
  }
}
