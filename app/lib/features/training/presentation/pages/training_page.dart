import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:runnin/features/coach/data/datasources/coach_report_remote_datasource.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/loading_widget.dart';
import 'package:runnin/shared/widgets/error_state_widget.dart';
import 'package:runnin/shared/widgets/empty_state_widget.dart';

enum _TrainingTab { plan, reports, adjustments }

enum _PlanMode { weekly, monthly }

const _settingsBoxName = 'runnin_settings';
const _pendingPlanIdKey = 'pending_training_plan_id';
const _planPollInterval = Duration(seconds: 15);

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final _ds = PlanRemoteDatasource();
  final _runDs = RunRemoteDatasource();
  final _reportDs = CoachReportRemoteDatasource();
  final _userDs = UserRemoteDatasource();
  UserProfile? _profile;
  Plan? _plan;
  List<_RunFeedback> _reports = const [];
  bool _loading = true;
  bool _generating = false;
  bool _checkingPlan = false;
  String? _pendingPlanId;
  String? _planCheckError;
  String? _error;
  DateTime? _lastPlanCheckAt;
  Timer? _planPollTimer;
  int _selectedWeek = 0;
  _TrainingTab _selectedTab = _TrainingTab.plan;
  _PlanMode _planMode = _PlanMode.weekly;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _planPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _planCheckError = null;
    });
    try {
      final savedPendingPlanId = await _readPendingPlanId();
      final results = await Future.wait([
        _userDs.getMe(),
        _ds.getCurrentPlan(),
        _loadRunFeedback(),
      ]);
      final profile = results[0] as UserProfile?;
      var plan = results[1] as Plan?;
      final reports = results[2] as List<_RunFeedback>;

      if (plan == null && savedPendingPlanId != null) {
        try {
          plan = await _ds.getPlanById(savedPendingPlanId);
        } catch (_) {
          await _clearPendingPlanId();
        }
      }

      final pendingPlanId = plan?.isGenerating == true ? plan!.id : null;
      if (pendingPlanId == null && savedPendingPlanId != null) {
        await _clearPendingPlanId();
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _plan = plan;
          _reports = reports;
          _generating = plan?.isGenerating ?? false;
          _pendingPlanId = pendingPlanId;
          _loading = false;
        });
      }
      if (pendingPlanId != null) {
        _startPlanPolling(pendingPlanId);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar plano.';
          _generating = false;
          _loading = false;
        });
      }
    }
  }

  Future<Box<dynamic>> _settingsBox() async {
    if (Hive.isBoxOpen(_settingsBoxName)) {
      return Hive.box<dynamic>(_settingsBoxName);
    }
    return Hive.openBox<dynamic>(_settingsBoxName);
  }

  Future<String?> _readPendingPlanId() async {
    final value = (await _settingsBox()).get(_pendingPlanIdKey);
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  Future<void> _savePendingPlanId(String planId) async {
    await (await _settingsBox()).put(_pendingPlanIdKey, planId);
  }

  Future<void> _clearPendingPlanId() async {
    await (await _settingsBox()).delete(_pendingPlanIdKey);
  }

  Future<List<_RunFeedback>> _loadRunFeedback() async {
    final runs = await _runDs.listRuns(limit: 12);
    final completedRuns =
        runs
            .where(
              (run) => run.status == 'completed' && run.coachReportId != null,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final reports = <_RunFeedback>[];
    for (final run in completedRuns) {
      try {
        final report = await _reportDs.getReport(run.id);
        if (!report.isReady) continue;
        reports.add(
          _RunFeedback(
            run: run,
            summary: report.summary!,
            generatedAt: report.generatedAt,
            isLatest: reports.isEmpty,
          ),
        );
      } catch (_) {
        // Ignora relatórios pendentes/indisponíveis para manter a página útil.
      }
    }
    return reports;
  }

  void _startPlanPolling(String planId) {
    _planPollTimer?.cancel();
    _planPollTimer = Timer.periodic(
      _planPollInterval,
      (_) => _checkPlanStatus(planId),
    );
  }

  Future<void> _checkPendingPlan() async {
    final planId = _pendingPlanId ?? _plan?.id;
    if (planId == null) return;
    await _checkPlanStatus(planId, manual: true);
  }

  Future<void> _checkPlanStatus(String planId, {bool manual = false}) async {
    if (_checkingPlan || !mounted) return;
    setState(() {
      _checkingPlan = true;
      _planCheckError = null;
    });

    try {
      final plan = await _ds.getPlanById(planId);
      if (!mounted) return;

      setState(() {
        _plan = plan;
        _generating = plan.isGenerating;
        _pendingPlanId = plan.isGenerating ? plan.id : null;
        _lastPlanCheckAt = DateTime.now();
      });

      if (plan.isGenerating) return;

      _planPollTimer?.cancel();
      await _clearPendingPlanId();

      final reports = await _loadRunFeedback();
      if (!mounted) return;
      setState(() {
        _reports = reports;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _planCheckError = manual
            ? 'Ainda nao conseguimos atualizar o status. Tente novamente em instantes.'
            : null;
        _lastPlanCheckAt = DateTime.now();
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingPlan = false;
        });
      }
    }
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
      _planCheckError = null;
    });
    try {
      final profile = await _userDs.getMe();
      final goal = profile?.goal.trim();
      final level = profile?.level.trim();

      if (profile == null ||
          goal == null ||
          goal.isEmpty ||
          level == null ||
          level.isEmpty) {
        throw Exception('Perfil incompleto');
      }

      final planId = await _ds.generatePlan(
        goal: goal,
        level: level,
        frequency: profile.frequency,
      );
      await _savePendingPlanId(planId);
      if (!mounted) return;
      setState(() {
        _pendingPlanId = planId;
        _lastPlanCheckAt = null;
        _plan = Plan(
          id: planId,
          goal: goal,
          level: level,
          weeksCount: _estimatePlanWeeks(
            goal: goal,
            level: level,
            frequency: profile.frequency,
          ),
          status: 'generating',
          weeks: const [],
          createdAt: DateTime.now().toIso8601String(),
        );
      });
      _startPlanPolling(planId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _generating = false;
          _pendingPlanId = null;
          _error =
              'Nao foi possivel gerar seu plano agora. Confira se seu perfil e objetivo estao preenchidos.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(title: 'TREINO'),
              const SizedBox(height: 20),
              _buildBody(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const LoadingWidget(
        fullScreen: true,
        message: 'Carregando plano de treino...',
      );
    }

    if (_error != null) {
      return ErrorStateWidget(
        message: _error!,
        onRetry: _load,
        fullScreen: true,
        icon: Icons.error_outline,
      );
    }

    if (_plan == null) {
      return _EmptyState(generating: _generating, onGenerate: _generate);
    }

    if (_plan!.isGenerating) {
      return _PlanGeneratingState(
        planId: _pendingPlanId ?? _plan!.id,
        checking: _checkingPlan,
        lastCheckedAt: _lastPlanCheckAt,
        error: _planCheckError,
        progress: _plan!.generationProgress,
        onCheck: _checkPendingPlan,
      );
    }

    if (_plan!.status == 'failed') {
      return _PlanFailedState(generating: _generating, onGenerate: _generate);
    }

    return _TrainingWorkspace(
      plan: _plan!,
      profile: _profile,
      reports: _reports,
      generating: _generating,
      onRegenerate: _generate,
      selectedWeek: _selectedWeek,
      selectedTab: _selectedTab,
      planMode: _planMode,
      onWeekChanged: (week) => setState(() => _selectedWeek = week),
      onTabChanged: (tab) => setState(() => _selectedTab = tab),
      onPlanModeChanged: (mode) => setState(() => _planMode = mode),
    );
  }
}

int _estimatePlanWeeks({
  required String goal,
  required String level,
  int? frequency,
}) {
  final normalizedGoal = goal
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c');
  final freq = (frequency ?? 3).clamp(1, 7);
  final isBeginner = level == 'iniciante';
  final isAdvanced = level == 'avancado';

  var weeks = switch (normalizedGoal) {
    final value when value.contains('maratona') || value.contains('42') =>
      isAdvanced ? 14 : 16,
    final value
        when value.contains('meia') ||
            value.contains('21') ||
            value.contains('half') =>
      isBeginner ? 14 : (isAdvanced ? 10 : 12),
    final value when value.contains('10k') || value.contains('10 km') =>
      isBeginner ? 10 : 8,
    final value when value.contains('5k') || value.contains('5 km') =>
      isBeginner ? 8 : 6,
    final value
        when value.contains('emagrec') ||
            value.contains('saude') ||
            value.contains('condicion') =>
      isAdvanced ? 6 : 8,
    _ => isBeginner ? 8 : (isAdvanced ? 10 : 8),
  };

  if (freq <= 2) {
    weeks += 2;
  } else if (freq >= 5 && !isBeginner && weeks > 8) {
    weeks -= 2;
  }

  return weeks.clamp(4, 16);
}

class _EmptyState extends StatelessWidget {
  final bool generating;
  final VoidCallback onGenerate;

  const _EmptyState({required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: AppPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_run_outlined,
                size: 48,
                color: palette.border,
              ),
              const SizedBox(height: 16),
              Text('Nenhum plano ativo', style: context.runninType.displaySm),
              const SizedBox(height: 8),
              Text(
                'Gere seu plano de treino personalizado com IA. Leva em conta seu nível e objetivo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: generating ? null : onGenerate,
                  child: generating
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.background,
                          ),
                        )
                      : const Text('GERAR MEU PLANO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanGeneratingState extends StatelessWidget {
  final String planId;
  final bool checking;
  final DateTime? lastCheckedAt;
  final String? error;
  final GenerationProgress? progress;
  final VoidCallback onCheck;

  const _PlanGeneratingState({
    required this.planId,
    required this.checking,
    required this.lastCheckedAt,
    required this.error,
    this.progress,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final shortPlanId = planId.length <= 8 ? planId : planId.substring(0, 8);
    final lastCheckedLabel = lastCheckedAt == null
        ? 'Aguardando primeira verificacao'
        : 'Ultima verificacao: ${DateFormat('HH:mm').format(lastCheckedAt!.toLocal())}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: AppPanel(
          padding: const EdgeInsets.all(24),
          borderColor: palette.primary.withValues(alpha: 0.28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               if (progress != null) ...[
                 EightStageLoadingWidget(
                   progress: progress!,
                 ),
                 const SizedBox(height: 20),
                Text(
                  progress!.stageName,
                  style: context.runninType.displaySm,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  progress!.stageDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: palette.primary,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Iniciando geração',
                  style: context.runninType.displaySm,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Preparando motor de IA para criar seu plano personalizado...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AppTag(label: 'ID $shortPlanId', color: palette.primary),
              const SizedBox(height: 12),
              Text(
                lastCheckedLabel,
                style: TextStyle(color: palette.border, fontSize: 12),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: checking ? null : onCheck,
                  child: checking
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.primary,
                          ),
                        )
                      : const Text('VERIFICAR STATUS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanFailedState extends StatelessWidget {
  final bool generating;
  final VoidCallback onGenerate;

  const _PlanFailedState({required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: AppPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: palette.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Nao foi possivel finalizar seu plano',
                style: context.runninType.displaySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A geracao falhou e nao vamos preencher com mock. Tente gerar novamente para buscar um plano real.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: generating ? null : onGenerate,
                  child: const Text('TENTAR NOVAMENTE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingWorkspace extends StatelessWidget {
  final Plan plan;
  final UserProfile? profile;
  final List<_RunFeedback> reports;
  final bool generating;
  final VoidCallback onRegenerate;
  final int selectedWeek;
  final _TrainingTab selectedTab;
  final _PlanMode planMode;
  final ValueChanged<int> onWeekChanged;
  final ValueChanged<_TrainingTab> onTabChanged;
  final ValueChanged<_PlanMode> onPlanModeChanged;

  const _TrainingWorkspace({
    required this.plan,
    required this.profile,
    required this.reports,
    required this.generating,
    required this.onRegenerate,
    required this.selectedWeek,
    required this.selectedTab,
    required this.planMode,
    required this.onWeekChanged,
    required this.onTabChanged,
    required this.onPlanModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _PlanContextCard(
            plan: plan,
            profile: profile,
            generating: generating,
            onRegenerate: onRegenerate,
          ),
          const SizedBox(height: 12),
          _TopTabs(
            selectedTab: selectedTab,
            reportsCount: reports.length,
            adjustmentsCount: 0,
            onChanged: onTabChanged,
          ),
          const SizedBox(height: 16),
          switch (selectedTab) {
            _TrainingTab.plan => _PlanTab(
              plan: plan,
              selectedWeek: selectedWeek,
              planMode: planMode,
              onWeekChanged: onWeekChanged,
              onPlanModeChanged: onPlanModeChanged,
            ),
            _TrainingTab.reports => _ReportsTab(reports: reports),
            _TrainingTab.adjustments => const _AdjustmentsTab(),
          },
        ],
      ),
    );
  }
}

class _PlanContextCard extends StatelessWidget {
  final Plan plan;
  final UserProfile? profile;
  final bool generating;
  final VoidCallback onRegenerate;

  const _PlanContextCard({
    required this.plan,
    required this.profile,
    required this.generating,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final planDate = DateTime.tryParse(plan.createdAt);
    final planDateLabel = planDate == null
        ? '--'
        : DateFormat('dd/MM/yyyy HH:mm').format(planDate.toLocal());
    final profileSummary = profile == null
        ? 'Perfil nao carregado'
        : '${profile!.goal} · ${profile!.level} · ${profile!.frequency}x/sem';
    final planSummary =
        '${plan.goal} · ${plan.level} · ${plan.weeksCount} semanas';

    return AppPanel(
      color: palette.surfaceAlt,
      borderColor: palette.primary.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppTag(label: 'PLANO REAL', color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'Gerado em $planDateLabel',
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Plano pronto: $planSummary. Agora é executar com constância e ajustar quando o corpo pedir.',
            style: TextStyle(
              color: palette.text.withValues(alpha: 0.86),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Perfil usado para gerar: $profileSummary',
            style: TextStyle(
              color: palette.text.withValues(alpha: 0.86),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: generating ? null : onRegenerate,
              child: Text(
                generating ? 'GERANDO NOVO PLANO...' : 'GERAR NOVO PLANO',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  final _TrainingTab selectedTab;
  final int reportsCount;
  final int adjustmentsCount;
  final ValueChanged<_TrainingTab> onChanged;

  const _TopTabs({
    required this.selectedTab,
    required this.reportsCount,
    required this.adjustmentsCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            label: 'PLANO',
            selected: selectedTab == _TrainingTab.plan,
            onTap: () => onChanged(_TrainingTab.plan),
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          child: _TabButton(
            label: 'RELATÓRIOS',
            count: reportsCount,
            selected: selectedTab == _TrainingTab.reports,
            onTap: () => onChanged(_TrainingTab.reports),
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          child: _TabButton(
            label: 'AJUSTES',
            count: adjustmentsCount,
            selected: selectedTab == _TrainingTab.adjustments,
            onTap: () => onChanged(_TrainingTab.adjustments),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.08,
                color: selected ? palette.background : palette.muted,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                color: selected
                    ? palette.background.withValues(alpha: 0.12)
                    : palette.primary,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: selected ? palette.background : palette.background,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanTab extends StatelessWidget {
  final Plan plan;
  final int selectedWeek;
  final _PlanMode planMode;
  final ValueChanged<int> onWeekChanged;
  final ValueChanged<_PlanMode> onPlanModeChanged;

  const _PlanTab({
    required this.plan,
    required this.selectedWeek,
    required this.planMode,
    required this.onWeekChanged,
    required this.onPlanModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final week = plan.weeks.isNotEmpty
        ? plan.weeks[selectedWeek.clamp(0, plan.weeks.length - 1)]
        : null;
    final orderedSessions = [...?week?.sessions]
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final totalDistance = orderedSessions.fold<double>(
      0,
      (sum, session) => sum + session.distanceKm,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekNavigationButtons(
          currentWeek: selectedWeek,
          totalWeeks: plan.weeks.length,
          onPrevious: () => onWeekChanged((selectedWeek - 1).clamp(0, plan.weeks.length - 1)),
          onNext: () => onWeekChanged((selectedWeek + 1).clamp(0, plan.weeks.length - 1)),
        ),
        const SizedBox(height: 16),
        _buildWeekSelector(context),
        const SizedBox(height: 16),
        switch (planMode) {
          _PlanMode.weekly => _WeeklyPlanView(
            plan: plan,
            selectedWeek: selectedWeek,
            onWeekChanged: onWeekChanged,
          ),
          _PlanMode.monthly => _MonthlyPlanView(plan: plan),
        },
      ],
    );
  }
}

class _DualModeToggle extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;

  const _DualModeToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onLeftTap,
    required this.onRightTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeButton(
            label: leftLabel,
            selected: leftSelected,
            onTap: onLeftTap,
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          child: _ModeButton(
            label: rightLabel,
            selected: !leftSelected,
            onTap: onRightTap,
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: selected ? palette.surfaceAlt : palette.surface,
          border: Border.all(
            color: selected
                ? palette.primary.withValues(alpha: 0.5)
                : palette.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.08,
            color: selected ? palette.primary : palette.muted,
          ),
        ),
      ),
    );
  }
}

Widget _buildWeekSelector(BuildContext context) {
  final palette = context.runninPalette;
  
  return Consumer<TrainingState>(
    builder: (context, state, _) {
      final plan = state.plan;
      final selectedWeek = state.selectedWeek?.toInt() ?? 0;
      
      if (plan == null || plan.weeks.isEmpty) {
        return const SizedBox(height: 50);
      }
      
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 24),
            const SizedBox(height: 8),
            Text(
              'Selecionar Semana',
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 60),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: plan.weeks.length,
                itemBuilder: (_, index) {
                  return _WeekChip(
                    weekNumber: plan.weeks[index].weekNumber,
                    selected: index == selectedWeek,
                    onTap: () {
                      context.read<TrainingCubit>().selectWeek(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _WeeklyPlanView extends StatelessWidget {
  final Plan plan;
  final int selectedWeek;
  final ValueChanged<int> onWeekChanged;

  const _WeeklyPlanView({
    required this.plan,
    required this.selectedWeek,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final week = plan.weeks.isNotEmpty
        ? plan.weeks[selectedWeek.clamp(0, plan.weeks.length - 1)]
        : null;
    final orderedSessions = [...?week?.sessions]
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final totalDistance = orderedSessions.fold<double>(
      0,
      (sum, session) => sum + session.distanceKm,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: plan.weeks.length,
            itemBuilder: (_, index) {
              final isSelected = index == selectedWeek;
              return _WeekChip(
                weekNumber: index + 1,
                selected: isSelected,
                onTap: () => onWeekChanged(index),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: 'PLANO SEMANAL',
          indexLabel: '01',
          subtitle: _buildWeekHeadline(week),
        ),
        const SizedBox(height: 12),
        CoachNarrativeCard(text: _buildWeekSummary(week)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'VOLUME',
                value: '${totalDistance.toStringAsFixed(0)}K',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'SESSÕES',
                value: '${orderedSessions.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'DESCANSO',
                value: '${7 - orderedSessions.length}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(7, (index) {
          final day = index + 1;
          final sessionForDay = orderedSessions
              .where((session) => session.dayOfWeek == day)
              .firstOrNull;
          final isToday = day == DateTime.now().weekday;
          final isDone = day < DateTime.now().weekday && sessionForDay != null;
          return _WeeklySessionRow(
            dayOfWeek: day,
            session: sessionForDay,
            week: week,
            planId: plan.id,
            isToday: isToday,
            isDone: isDone,
          );
        }),
      ],
    );
  }
}

class _MonthlyPlanView extends StatelessWidget {
  final Plan plan;

  const _MonthlyPlanView({required this.plan});

  @override
  Widget build(BuildContext context) {
    final stats = _buildMonthlyStats(plan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'PERIODIZAÇÃO',
          indexLabel: '01',
          subtitle: 'Mesociclo 1 · Objetivo: ${plan.goal}',
        ),
        const SizedBox(height: 8),
        _PeriodizationVisual(plan.weeks),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: 'VOL TOTAL',
                value: '${stats.totalKm.toStringAsFixed(0)}K',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'SESSÕES',
                value: '${stats.totalSessions}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(
                label: 'DIAS TREINO',
                value: '${stats.totalSessions}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MetricCard(label: 'DESCANSO', value: '${stats.restDays}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...plan.weeks.asMap().entries.map((entry) {
          final weekIndex = entry.key;
          final week = entry.value;
          final weekDistance = week.sessions.fold<double>(
            0,
            (sum, session) => sum + session.distanceKm,
          );
          final currentWeekIndex = _currentPlanWeekIndex(plan);
          final isCompleted = weekIndex < currentWeekIndex;
          final isCurrent = weekIndex == currentWeekIndex;
          final status = isCompleted
              ? 'COMPLETA'
              : isCurrent
              ? 'ATUAL'
              : 'PRÓXIMA';
          return _MonthlyWeekCard(
            weekNumber: week.weekNumber,
            focus: _deriveWeekFocus(week),
            summary: _buildMonthSummary(week),
            totalDistance: weekDistance,
            status: status,
            isRecoveryWeek: week.isRecoveryWeek,
            statusColor: isCompleted
                ? context.runninPalette.primary
                : isCurrent
                ? context.runninPalette.secondary
                : context.runninPalette.muted,
          );
        }),
      ],
    );
  }
}

class _PeriodizationVisual extends StatelessWidget {
  final List<PlanWeek> weeks;

  const _PeriodizationVisual(this.weeks);

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Column(
            children: weeks.asMap().entries.map((entry) {
              final index = entry.key;
              final week = entry.value;
              final isRecovery = week.isRecoveryWeek;
              final intensityLevel = _calculateIntensityLevel(week);
              final currentWeekIndex = _currentPlanWeekIndex(weeks.first.plan);

              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 100,
                    padding: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: palette.border, width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        _IntensityBar(
                          intensityLevel: intensityLevel,
                          isRecovery: isRecovery,
                          weekIndex: index,
                          currentWeekIndex: currentWeekIndex,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PeriodizationLegend(),
              const SizedBox(height: 12),
              Text(
                'Modelo 3:1',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: palette.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '3 semanas de carga progressiva → 1 semana de descanso',
                style: TextStyle(
                  fontSize: 10,
                  color: palette.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateIntensityLevel(PlanWeek week) {
    if (week.isRecoveryWeek) return 1;
    final totalDistance = week.sessions.fold<double>(0, (sum, s) => sum + s.distanceKm);
    if (totalDistance < 20) return 1;
    if (totalDistance < 35) return 2;
    if (totalDistance < 50) return 3;
    return 4;
  }
}

class _IntensityBar extends StatelessWidget {
  final int intensityLevel;
  final bool isRecovery;
  final int weekIndex;
  final int currentWeekIndex;

  const _IntensityBar({
    required this.intensityLevel,
    required this.isRecovery,
    required this.weekIndex,
    required this.currentWeekIndex,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final totalSlots = 4;

    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(totalSlots, (slotIndex) {
          final isFilled = slotIndex < intensityLevel;
          final isActive = weekIndex == currentWeekIndex && slotIndex == intensityLevel - 1;

          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            width: double.infinity,
            height: (isFilled || isActive) ? 18 : 4,
            decoration: BoxDecoration(
              color: isRecovery
                  ? palette.border.withValues(alpha: 0.4)
                  : (isFilled
                      ? palette.secondary
                      : isActive
                          ? palette.primary
                          : palette.border.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

class _PeriodizationLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendColorBox(label: 'Recuperação', color: palette.border.withValues(alpha: 0.4)),
        const SizedBox(width: 12),
        _LegendColorBox(label: 'Baixa', color: palette.secondary.withValues(alpha: 0.3)),
        const SizedBox(width: 12),
        _LegendColorBox(label: 'Média', color: palette.secondary.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        _LegendColorBox(label: 'Alta', color: palette.primary),
      ],
    );
  }
}

class _LegendColorBox extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendColorBox({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 8, color: context.runninPalette.muted),
        ),
      ],
    );
  }
}

class _ReportsTab extends StatelessWidget {
  final List<_RunFeedback> reports;

  const _ReportsTab({required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _TabEmptyState(
        title: 'Nenhum feedback de IA ainda',
        body:
            'Os feedbacks reais aparecem aqui depois que voce conclui corridas com relatorio tecnico gerado pelo Coach.AI.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'FEEDBACKS DA IA',
          indexLabel: '01',
          subtitle:
              'Analises tecnicas geradas a partir das suas corridas reais',
        ),
        const SizedBox(height: 12),
        ...reports.map((report) => _ReportCard(report: report)),
      ],
    );
  }
}

class _AdjustmentsTab extends StatelessWidget {
  const _AdjustmentsTab();

  @override
  Widget build(BuildContext context) {
    return const _TabEmptyState(
      title: 'Nenhum ajuste real ainda',
      body:
          'Quando o fluxo de revisao de plano estiver conectado a execucao real, o historico aparecera aqui. Por enquanto, nao exibimos ajustes simulados.',
    );
  }
}

class _WeekChip extends StatelessWidget {
  final int weekNumber;
  final bool selected;
  final VoidCallback onTap;

  const _WeekChip({
    required this.weekNumber,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          'S$weekNumber',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? palette.background : palette.muted,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String indexLabel;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.indexLabel,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(title, style: context.runninType.displayMd),
            const SizedBox(width: 6),
            Text(
              indexLabel,
              style: TextStyle(
                color: palette.primary,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: palette.muted)),
      ],
    );
  }
}

class _TabEmptyState extends StatelessWidget {
  final String title;
  final String body;

  const _TabEmptyState({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppPanel(
          color: palette.surfaceAlt,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 40, color: palette.border),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.runninType.displaySm,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklySessionRow extends StatelessWidget {
  final int dayOfWeek;
  final PlanSession? session;
  final PlanWeek? week;
  final String planId;
  final bool isToday;
  final bool isDone;

  const _WeeklySessionRow({
    required this.dayOfWeek,
    required this.session,
    this.week,
    required this.planId,
    required this.isToday,
    required this.isDone,
  });

  static const _dayNames = [
    '',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final isRest = session == null;

    return GestureDetector(
      onTap: isRest || week == null ? null : () => _openSessionDetail(context),
      child: AppPanel(
        margin: const EdgeInsets.only(bottom: 8),
        color: isToday ? palette.surfaceAlt : palette.surface,
        borderColor: isToday
            ? palette.primary.withValues(alpha: 0.4)
            : palette.border,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  color: isDone
                      ? palette.primary
                      : isToday
                      ? palette.primary.withValues(alpha: 0.15)
                      : palette.surfaceAlt,
                  child: Text(
                    isDone
                        ? 'OK'
                        : (isToday
                              ? 'HOJE'
                              : _dayNames[dayOfWeek].substring(0, 3).toUpperCase()),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: isDone
                          ? palette.background
                          : (isToday ? palette.primary : palette.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dayNames[dayOfWeek],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRest ? 'Descanso' : session!.type,
                        style: TextStyle(color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isRest)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SessionMetricsRow(session: session!),
                    if (session!.warmupDuration.isNotEmpty || session!.cooldownDuration.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            if (session!.warmupDuration.isNotEmpty)
                              _MiniMetric(label: 'AQUEC', value: session!.warmupDuration),
                            if (session!.cooldownDuration.isNotEmpty)
                              _MiniMetric(label: 'DESC', value: session!.cooldownDuration),
                          ],
                        ),
                      ),
                    if (session!.targetHeartRateMin != null && session!.targetHeartRateMax != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _HeartRateZoneCard(
                          min: session!.targetHeartRateMin!,
                          max: session!.targetHeartRateMax!,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openSessionDetail(BuildContext context) {
    if (session == null || week == null) return;
    context.go('/session-detail', extra: {
      'session': session,
      'week': week,
      'planId': planId,
    });
  }

  String _distanceLabel(PlanSession session) {
    if (session.type.toLowerCase().contains('interval')) {
      return '${session.distanceKm.toStringAsFixed(1)}K';
    }
    if (session.distanceKm == session.distanceKm.truncateToDouble()) {
      return '${session.distanceKm.toStringAsFixed(0)}K';
    }
    return '${session.distanceKm.toStringAsFixed(1)}K';
  }
}

class _SessionMetricsRow extends StatelessWidget {
  final PlanSession session;

  const _SessionMetricsRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.straighten, size: 14, color: palette.muted),
                const SizedBox(width: 4),
                Text(
                  '${session.distanceKm.toStringAsFixed(1)}K',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (session.targetPace != null)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 14, color: palette.muted),
                  const SizedBox(width: 4),
                  Text(
                    session.targetPace!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HeartRateZoneCard extends StatelessWidget {
  final int min;
  final int max;

  const _HeartRateZoneCard({required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.secondary.withValues(alpha: 0.12),
        border: Border.all(
          color: palette.secondary.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite, size: 14, color: palette.secondary),
          const SizedBox(width: 6),
          Text(
            '$min-$max bpm',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: palette.muted),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

  void _openSessionDetail(BuildContext context) {
    if (session == null || week == null) return;
    context.go('/session-detail', extra: {
      'session': session,
      'week': week,
      'planId': planId,
    });
  }

  String _distanceLabel(PlanSession session) {
    if (session.type.toLowerCase().contains('interval')) {
      return '${session.distanceKm.toStringAsFixed(1)}K';
    }
    if (session.distanceKm == session.distanceKm.truncateToDouble()) {
      return '${session.distanceKm.toStringAsFixed(0)}K';
    }
    return '${session.distanceKm.toStringAsFixed(1)}K';
  }
}

class _MonthlyWeekCard extends StatelessWidget {
  final int weekNumber;
  final String focus;
  final String summary;
  final double totalDistance;
  final String status;
  final bool isRecoveryWeek;
  final Color statusColor;

  const _MonthlyWeekCard({
    required this.weekNumber,
    required this.focus,
    required this.summary,
    required this.totalDistance,
    required this.status,
    required this.isRecoveryWeek,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRecoveryWeek ? palette.surfaceAlt : null,
      borderColor: status == 'ATUAL'
          ? palette.primary.withValues(alpha: 0.45)
          : isRecoveryWeek
              ? palette.secondary.withValues(alpha: 0.3)
              : palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRecoveryWeek)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppTag(
                label: 'SEMANA DE RECUPERAÇÃO (3:1)',
                color: palette.secondary.withValues(alpha: 0.7),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sem $weekNumber  Foco: $focus',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      style: TextStyle(color: palette.muted, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${totalDistance.toStringAsFixed(0)}K',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: palette.secondary,
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.08,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final _RunFeedback report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      color: report.isLatest ? palette.surfaceAlt : null,
      borderColor: report.isLatest
          ? palette.primary.withValues(alpha: 0.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: palette.text,
                  ),
                ),
              ),
              if (report.isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  color: palette.primary,
                  child: Text(
                    'MAIS RECENTE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: palette.background,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricColumn(label: 'DATA', value: report.dateLabel),
              ),
              Expanded(
                child: _MetricColumn(
                  label: 'KM',
                  value: report.totalKm.toStringAsFixed(2),
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  label: 'TEMPO',
                  value: report.durationLabel,
                ),
              ),
              Expanded(
                child: _MetricColumn(label: 'PACE', value: report.paceLabel),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.coachSummary,
            style: TextStyle(
              color: palette.text.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          AppTag(label: 'RELATORIO REAL', color: palette.primary),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;

  const _MetricColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: palette.muted,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: palette.secondary,
          ),
        ),
      ],
    );
  }
}

class _MonthlyStats {
  final double totalKm;
  final int totalSessions;
  final int restDays;

  const _MonthlyStats({
    required this.totalKm,
    required this.totalSessions,
    required this.restDays,
  });
}

class _RunFeedback {
  final Run run;
  final String summary;
  final String? generatedAt;
  final bool isLatest;

  const _RunFeedback({
    required this.run,
    required this.summary,
    required this.generatedAt,
    required this.isLatest,
  });

  String get title => run.type.toUpperCase();

  String get dateLabel {
    final parsed = DateTime.tryParse(run.createdAt);
    if (parsed == null) return '--/--';
    return DateFormat('dd/MM').format(parsed.toLocal());
  }

  double get totalKm => run.distanceM / 1000;

  String get durationLabel => _formatDuration(run.durationS);

  String get paceLabel => run.avgPace ?? '--:--';

  String get coachSummary => summary;
}

_MonthlyStats _buildMonthlyStats(Plan plan) {
  final totalSessions = plan.weeks.fold<int>(
    0,
    (sum, week) => sum + week.sessions.length,
  );
  final totalKm = plan.weeks.fold<double>(
    0,
    (sum, week) =>
        sum +
        week.sessions.fold<double>(
          0,
          (sessionSum, session) => sessionSum + session.distanceKm,
        ),
  );
  return _MonthlyStats(
    totalKm: totalKm,
    totalSessions: totalSessions,
    restDays: (plan.weeks.length * 7) - totalSessions,
  );
}

int _currentPlanWeekIndex(Plan plan) {
  if (plan.weeks.isEmpty) return 0;

  final createdAt = DateTime.tryParse(plan.createdAt);
  if (createdAt == null) return 0;

  final elapsedDays = DateTime.now().difference(createdAt).inDays;
  if (elapsedDays <= 0) return 0;

  return (elapsedDays ~/ 7).clamp(0, plan.weeks.length - 1);
}

String _buildWeekHeadline(PlanWeek? week) {
  if (week == null) return 'Semana sem sessoes planejadas';
  final totalKm = week.sessions.fold<double>(
    0,
    (sum, session) => sum + session.distanceKm,
  );
  return 'Semana ${week.weekNumber} · ${week.sessions.length} sessoes · ${totalKm.toStringAsFixed(1)} km';
}

String _buildWeekSummary(PlanWeek? week) {
  if (week == null || week.sessions.isEmpty) {
    return 'Semana livre no plano. Use para recuperar bem e chegar inteiro no proximo bloco.';
  }

  final ordered = [...week.sessions]
    ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
  final sessionTypes = ordered.map((item) => item.type).toSet().join(', ');
  final notes = ordered
      .map((item) => item.notes.trim())
      .where((item) => item.isNotEmpty)
      .take(3)
      .join(' ');

  if (notes.isEmpty) {
    return 'Nesta semana vamos combinar $sessionTypes. Mantem constancia, respeita os dias leves e chega forte no treino-chave.';
  }

  return 'Nesta semana vamos combinar $sessionTypes. $notes';
}

String _deriveWeekFocus(PlanWeek week) {
  final sessionTypes = week.sessions
      .map((session) => session.type.toLowerCase())
      .toList();
  if (sessionTypes.any((item) => item.contains('interval'))) {
    return 'Velocidade';
  }
  if (sessionTypes.any((item) => item.contains('tempo'))) {
    return 'Ritmo';
  }
  if (sessionTypes.any((item) => item.contains('long'))) {
    return 'Resistencia';
  }
  return 'Base';
}

String _buildMonthSummary(PlanWeek week) {
  final ordered = [...week.sessions]
    ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
  final summaryParts = ordered
      .map((session) => '${_shortDayName(session.dayOfWeek)} ${session.type}')
      .join(' · ');
  final note = ordered
      .map((session) => session.notes.trim())
      .firstWhere((item) => item.isNotEmpty, orElse: () => '');

  if (note.isEmpty) return summaryParts;
  return '$summaryParts. $note';
}

String _shortDayName(int dayOfWeek) {
  const names = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
  return names[dayOfWeek];
}

  String _formatDuration(int durationS) {
    final minutes = durationS ~/ 60;
    final seconds = durationS % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

class _WeekNavigationButtons extends StatelessWidget {
  final int currentWeek;
  final int totalWeeks;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _WeekNavigationButtons({
    required this.currentWeek,
    required this.totalWeeks,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: currentWeek == 0 ? null : onPrevious,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: Text(
              'Semana ${currentWeek > 0 ? currentWeek : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (totalWeeks > 1)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: currentWeek == totalWeeks - 1 ? null : onNext,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: Text(
                'Semana ${currentWeek < totalWeeks - 1 ? currentWeek + 2 : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
