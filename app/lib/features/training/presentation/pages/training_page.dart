import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:runnin/features/coach/data/datasources/coach_report_remote_datasource.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/data/weekly_report_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/features/training/presentation/widgets/plan_closing_card.dart';
import 'package:runnin/features/training/domain/week_phase_label.dart';
import 'package:runnin/features/training/domain/entities/weekly_report.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/subscriptions/presentation/widgets/premium_locked_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/figma/figma_coach_ai_block.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/features/training/presentation/pages/adjustments_history_page.dart';

/// RELATÓRIOS saiu daqui — relatório de uma corrida vive em
/// /history/run/:id (user clica na corrida). TREINO foca em plano +
/// histórico de ajustes do mesociclo (checkpoints).
enum _TrainingTab { plan, adjustments }

enum _PlanMode { weekly, monthly }

const _settingsBoxName = 'runnin_settings';
const _pendingPlanIdKey = 'pending_training_plan_id';
const _planPollInterval = Duration(seconds: 3);

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
  final _weeklyReportDs = WeeklyReportRemoteDatasource();
  List<WeeklyReport> _weeklyReports = const [];
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
  // Garante que a semana atual (calculada via createdAt vs hoje) seja
  // selecionada na PRIMEIRA carga do plano. Depois disso, respeitamos a
  // navegação manual do usuário — não reescrevemos por cima da escolha dele.
  bool _weekAutoSelected = false;
  _TrainingTab _selectedTab = _TrainingTab.plan;
  // Mensal abre por padrão pra atleta ver mesociclo (visão macro) antes
  // do detalhe da semana corrente.
  _PlanMode _planMode = _PlanMode.monthly;

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
        _loadWeeklyReports(),
      ]);
      final profile = results[0] as UserProfile?;
      var plan = results[1] as Plan?;
      final reports = results[2] as List<_RunFeedback>;
      _weeklyReports = results[3] as List<WeeklyReport>;

      if (plan == null && savedPendingPlanId != null) {
        try {
          plan = await _ds.getPlanById(savedPendingPlanId);
        } catch (e, st) {
          Logger.warn('training.getPlanById_failed', context: {
            'planId': savedPendingPlanId,
            'err': '$e',
          });
          Logger.error('training.getPlanById_failed', e, st);
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
          if (plan != null &&
              !(plan.isGenerating) &&
              !_weekAutoSelected &&
              plan.weeks.isNotEmpty) {
            _selectedWeek = _currentPlanWeekIndex(plan);
            _weekAutoSelected = true;
          }
        });
      }
      if (pendingPlanId != null) {
        _startPlanPolling(pendingPlanId);
      }
    } catch (e, st) {
      Logger.error('training.load_failed', e, st);
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


  Future<List<WeeklyReport>> _loadWeeklyReports() async {
    try {
      return await _weeklyReportDs.getWeeklyReports();
    } catch (e, st) {
      Logger.error('training.loadWeeklyReports_failed', e, st);
      return [];
    }
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
      } catch (e, st) {
        // Ignora relatórios pendentes/indisponíveis para manter a página útil.
        // Log info-level (warn não-aria) pra não inundar Crashlytics.
        Logger.warn('training.report_unavailable', context: {
          'runId': run.id,
          'err': '$e',
        });
        // Stack trace só em debug; release não inflama o Crashlytics aqui.
        Logger.info('training.report_unavailable_stack', context: {'st': st.toString().split('\n').take(2).join(' ')});
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
        if (!plan.isGenerating &&
            !_weekAutoSelected &&
            plan.weeks.isNotEmpty) {
          _selectedWeek = _currentPlanWeekIndex(plan);
          _weekAutoSelected = true;
        }
      });

      if (plan.isGenerating) return;

      _planPollTimer?.cancel();
      await _clearPendingPlanId();

      final reports = await _loadRunFeedback();
      if (!mounted) return;
      setState(() {
        _reports = reports;
      });
    } catch (e, st) {
      Logger.error('training.checkPlanStatus_failed', e, st);
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

  /// Plano agora é criado na jornada /training/criar-plano (nível→meta→dias→
  /// pace→início), que faz o gate premium, a geração e a confirmação de
  /// substituição. Aqui só navegamos pra lá.
  void _openPlanSetup() {
    context.push('/training/criar-plano');
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
              const FigmaTopNav(breadcrumb: 'TREINO'),
              const SizedBox(height: 20),
              _buildBody(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final palette = context.runninPalette;

    // Gate freemium: plano + treino guiado são features Premium.
    // Em vez de carregar plano e mostrar empty state genérico, mostra
    // o card de paywall logo no topo da tela. Listenable rebuild quando
    // o user volta do paywall (subscriptionController.notifyListeners).
    return ListenableBuilder(
      listenable: subscriptionController,
      builder: (context, _) {
        if (!subscriptionController.isPro) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: PremiumLockedCard(
              title: 'TREINO PERSONALIZADO',
              description:
                  'O módulo de treino com plano gerado pelo coach AI, '
                  'distribuição semanal, ajustes automáticos e relatórios '
                  'é exclusivo do Premium. Suas corridas livres seguem '
                  'liberadas na home.',
              icon: Icons.fitness_center_outlined,
              next: '/training',
            ),
          );
        }
        return _buildAuthenticatedBody(context, palette);
      },
    );
  }

  Widget _buildAuthenticatedBody(BuildContext context, RunninPalette palette) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: palette.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: context.runninType.bodySm),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
          ],
        ),
      );
    }

    if (_plan == null) {
      return _EmptyState(generating: _generating, onGenerate: _openPlanSetup);
    }

    // Plano concluído → banner com 2 CTAs (relatório + novo plano) seguido
    // do estado "sem plano" (reusa _EmptyState). Aparece quando o server
    // detecta mesocycleEndDate < hoje (status lazy = completed).
    if (_plan!.isCompleted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanCompletedBanner(
            planId: _plan!.id,
            onSeeReport: () =>
                context.push('/training/plan-report/${_plan!.id}'),
            onNewPlan: _openPlanSetup,
          ),
          _EmptyState(generating: _generating, onGenerate: _openPlanSetup),
        ],
      );
    }

    if (_plan!.isGenerating) {
      return _PlanGeneratingState(
        planId: _pendingPlanId ?? _plan!.id,
        checking: _checkingPlan,
        lastCheckedAt: _lastPlanCheckAt,
        error: _planCheckError,
        onCheck: _checkPendingPlan,
      );
    }

    if (_plan!.status == 'failed') {
      return _PlanFailedState(generating: _generating, onGenerate: _openPlanSetup);
    }

    final workspace = _TrainingWorkspace(
      plan: _plan!,
      profile: _profile,
      reports: _reports,
      weeklyReports: _weeklyReports,
      generating: _generating,
      onRegenerate: _openPlanSetup,
      selectedWeek: _selectedWeek,
      selectedTab: _selectedTab,
      planMode: _planMode,
      onWeekChanged: (week) => setState(() => _selectedWeek = week),
      onTabChanged: (tab) => setState(() => _selectedTab = tab),
      onPlanModeChanged: (mode) => setState(() => _planMode = mode),
    );

    return workspace;
  }
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
                style: context.runninType.bodyMd.copyWith(color: palette.muted),
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
  final VoidCallback onCheck;

  const _PlanGeneratingState({
    required this.planId,
    required this.checking,
    required this.lastCheckedAt,
    required this.error,
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
                'Criando seu plano',
                style: context.runninType.displaySm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A criacao esta em progresso e pode levar alguns minutos.',
                textAlign: TextAlign.center,
                style: context.runninType.bodyMd.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 14),
              AppTag(label: 'ID $shortPlanId', color: palette.primary),
              const SizedBox(height: 12),
              Text(
                lastCheckedLabel,
                style: context.runninType.bodySm.copyWith(color: palette.border),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: context.runninType.bodySm.copyWith(color: palette.secondary),
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
                style: context.runninType.bodyMd.copyWith(color: palette.muted),
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
  final List<WeeklyReport> weeklyReports;

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
    required this.weeklyReports,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padronizado em xxl (~24) — bate com padding horizontal da home.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
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
            adjustmentsCount: plan.revisions.length,
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
            _TrainingTab.adjustments => AdjustmentsHistoryPage(planId: plan.id),
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
              AppTag(label: 'PLANO BASE', color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'Gerado em $planDateLabel',
                style: context.runninType.bodyXs,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'PLANO PRONTO: ${planSummary.toUpperCase()}. AGORA É EXECUTAR COM CONSTÂNCIA E AJUSTAR QUANDO O CORPO PEDIR.',
            style: context.runninType.labelCaps.copyWith(
              fontSize: 12,
              letterSpacing: 0.4,
              color: palette.text.withValues(alpha: 0.86),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Perfil usado para gerar: $profileSummary',
            style: context.runninType.bodyMd.copyWith(
              color: palette.text.withValues(alpha: 0.86),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/training/plan-detail'),
              icon: Icon(Icons.menu_book_outlined, size: 16, color: palette.background),
              label: const Text('VER PLANO BASE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.background,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // "GERAR NOVO PLANO" removido — regenerar plano vira ação restrita
          // (cooldown 1×/semana). Mantém só "VER PLANO COMPLETO" pra mostrar
          // o plano que o coach montou. Pra ajustes pontuais existe a aba
          // AJUSTES (revisão semanal) e auto-adapt pós-corrida.
        ],
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  final _TrainingTab selectedTab;
  final int adjustmentsCount;
  final ValueChanged<_TrainingTab> onChanged;

  const _TopTabs({
    required this.selectedTab,
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
            width: 1.041,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: context.runninType.labelCaps.copyWith(
                fontSize: 11,
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
                  style: context.runninType.labelCaps.copyWith(
                    fontSize: 9,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DualModeToggle(
          // Mensal primeiro: o atleta entende o mesociclo (visão macro)
          // antes de mergulhar na semana atual. Inversão é só visual; o
          // default _planMode continua weekly pra coerência com legado.
          leftLabel: 'MENSAL',
          rightLabel: 'SEMANAL',
          leftSelected: planMode == _PlanMode.monthly,
          onLeftTap: () => onPlanModeChanged(_PlanMode.monthly),
          onRightTap: () => onPlanModeChanged(_PlanMode.weekly),
        ),
        const SizedBox(height: 16),
        switch (planMode) {
          _PlanMode.weekly => _WeeklyPlanView(
            plan: plan,
            selectedWeek: selectedWeek,
            onWeekChanged: onWeekChanged,
          ),
          _PlanMode.monthly => _MonthlyPlanView(
            plan: plan,
            onWeekTap: (weekNumber) {
              // Volta pra visão SEMANAL com a semana clicada selecionada.
              // weekNumber é 1-based; selectedWeek é 0-based.
              onWeekChanged((weekNumber - 1).clamp(0, plan.weeks.length - 1));
              onPlanModeChanged(_PlanMode.weekly);
            },
          ),
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
            width: 1.041,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.runninType.labelCaps.copyWith(
            fontSize: 11,
            letterSpacing: 0.08,
            color: selected ? palette.primary : palette.muted,
          ),
        ),
      ),
    );
  }
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
              final isCurrent = index == plan.currentWeekIndex();
              // Última semana é a SEMANA DA META quando o plano tem
              // sessão-alvo marcada (RACE). Mostra label "META" abaixo.
              final isLastWeek = index == plan.weeks.length - 1;
              final hasTarget = isLastWeek &&
                  plan.weeks[index].sessions.any((s) => s.isTarget);
              return _WeekChip(
                weekNumber: index + 1,
                selected: isSelected,
                isCurrent: isCurrent,
                isTargetWeek: hasTarget,
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
        if (week?.isSkeleton ?? false) ...[
          _SkeletonWeekNotice(),
          const SizedBox(height: 12),
        ],
        ...() {
          // Datas reais por sessão: cada semana começa na segunda anterior
          // ao startDate (ou no próprio startDate se ele cair numa segunda).
          // Week 1 alinha com a semana civil do startDate; semanas seguintes
          // somam +7 dias.
          final today = DateTime.now();
          final todayDateOnly = DateTime(today.year, today.month, today.day);
          final planStart = plan.effectiveStartDate;
          final week1Monday = planStart.subtract(
            Duration(days: (planStart.weekday - 1) % 7),
          );
          final weekStartMonday = DateTime(
            week1Monday.year,
            week1Monday.month,
            week1Monday.day,
          ).add(Duration(days: selectedWeek * 7));
          final weekIsLocked = week?.isSkeleton ?? false;
          return List.generate(7, (index) {
            final day = index + 1;
            final dayDate = weekStartMonday.add(Duration(days: index));
            final isToday = dayDate.isAtSameMomentAs(todayDateOnly);
            final isPast = dayDate.isBefore(todayDateOnly);
            final sessionForDay = orderedSessions
                .where((s) => s.dayOfWeek == day)
                .firstOrNull;
            return _WeeklySessionRow(
              weekNumber: selectedWeek + 1,
              dayOfWeek: day,
              dayDate: dayDate,
              session: sessionForDay,
              isToday: isToday,
              isPast: isPast,
              isLocked: weekIsLocked,
              plan: plan,
            );
          });
        }(),
        // Última semana: card de fechamento (CHEGADA pra race, FECHAMENTO
        // pra flow). Aparece DEPOIS dos 7 dias pra fechar visualmente
        // a semana com o objetivo atingido.
        if (week != null && selectedWeek == plan.weeks.length - 1) ...[
          const SizedBox(height: 12),
          PlanClosingCard(plan: plan, lastWeek: week),
        ],
        const SizedBox(height: 16),
        // Volume da semana em barras (km por dia), similar ao mensal.
        _WeeklyVolumeBars(
          sessions: orderedSessions,
          todayDow: selectedWeek == _currentPlanWeekIndex(plan)
              ? DateTime.now().weekday
              : 0,
        ),
      ],
    );
  }
}

/// Barras de VOLUME por dia da semana (km de cada sessão). Dia de HOJE em cyan
/// sólido; demais dias com sessão em cyan suave; descanso fica vazio. Espelha o
/// gráfico de carga do mensal, mas no recorte diário.
class _WeeklyVolumeBars extends StatelessWidget {
  final List<PlanSession> sessions;
  final int todayDow; // 1..7 se HOJE está nesta semana; 0 caso contrário.
  const _WeeklyVolumeBars({required this.sessions, required this.todayDow});

  static const _dayShort = ['', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final byDay = <int, double>{};
    for (final s in sessions) {
      byDay[s.dayOfWeek] = (byDay[s.dayOfWeek] ?? 0) + s.distanceKm;
    }
    final loads = List.generate(7, (i) => byDay[i + 1] ?? 0.0);
    final maxLoad = loads.fold<double>(1, (m, l) => l > m ? l : m);
    const maxBarH = 80.0;
    const minBarH = 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOLUME DA SEMANA',
          style: type.labelCaps.copyWith(
            color: palette.muted,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final dow = i + 1;
            final load = loads[i];
            final isToday = dow == todayDow;
            final hasRun = load > 0;
            final barColor = !hasRun
                ? palette.border
                : isToday
                    ? palette.primary
                    : palette.primary.withValues(alpha: 0.3);
            final h = hasRun ? minBarH + (load / maxLoad) * (maxBarH - minBarH) : 6.0;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasRun ? '${load.toStringAsFixed(0)}K' : '·',
                      style: type.labelCaps.copyWith(
                        color: isToday ? palette.primary : palette.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(height: h, color: barColor),
                    const SizedBox(height: 5),
                    Text(
                      _dayShort[dow],
                      style: type.labelCaps.copyWith(
                        color: isToday ? palette.primary : palette.muted,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _MonthlyPlanView extends StatelessWidget {
  final Plan plan;
  final ValueChanged<int> onWeekTap;

  const _MonthlyPlanView({required this.plan, required this.onWeekTap});

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
        const SizedBox(height: 12),
        // Grid 2×2: numa única linha de 4, os labels longos (VOL TOTAL,
        // DIAS TREINO, DESCANSO) não cabiam e quebravam/cortavam. 2 por linha
        // dá largura suficiente — mesmo padrão do Histórico/DADOS.
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
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
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
        // Mostra TODAS as semanas do mesociclo. As que ainda não foram
        // detalhadas (skeleton) aparecem com cadeado e dialog ao tocar; a
        // regra D+15 é entregue pelo server via detailLevel + enrichTwoTier
        // a cada checkpoint aceito.
        ...plan.weeks.asMap().entries.map((entry) {
          final weekIndex = entry.key;
          final week = entry.value;
          final currentWeekIndex = _currentPlanWeekIndex(plan);
          // "COMPLETA" vem da execução real (executedRunId), não da data.
          final executed = week.sessions.where((s) => s.isExecuted).length;
          final allDone =
              week.sessions.isNotEmpty && executed == week.sessions.length;
          final isCurrent = weekIndex == currentWeekIndex;
          final isPast = weekIndex < currentWeekIndex;
          final status = allDone
              ? 'COMPLETA'
              : isCurrent
              ? 'ATUAL'
              : isPast
              ? 'PARCIAL'
              : 'PRÓXIMA';
          final statusColor = allDone
              ? context.runninPalette.primary // COMPLETA = cyan
              : isCurrent
              ? context.runninPalette.text // ATUAL = claro (destaque neutro)
              : isPast
              ? context.runninPalette.warning
              : context.runninPalette.muted; // PRÓXIMA = apagado
          return _MonthlyWeekCard(
            plan: plan,
            week: week,
            status: status,
            statusColor: statusColor,
            onTap: () => onWeekTap(week.weekNumber),
          );
        }),
        const SizedBox(height: 8),
        // Resumo de carga (km projetados) das 4 primeiras semanas, em barras.
        // Limitamos a 4 aqui pra o gráfico não virar uma fileira ilegível em
        // planos longos — a leitura semana-a-semana acontece nos cards acima.
        _CargaBars(
          weeks: plan.weeks.take(4).toList(),
          currentWeekIndex: _currentPlanWeekIndex(plan),
        ),
        const SizedBox(height: 16),
        // Box estática explicando a regra do detalhe progressivo (D+15).
        FigmaCoachAIBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FigmaCoachAIBreadcrumb(action: 'PERIODIZAÇÃO'),
              const SizedBox(height: 10),
              Text(
                'O coach detalha sempre as duas próximas semanas (≈ 15 dias). '
                'As demais aparecem com cadeado — ele evolui a partir dos seus '
                'números reais, então o detalhe é liberado a cada checkpoint '
                'semanal, sem prometer o que ainda vai depender da sua semana.',
                style: context.runninType.bodySm.copyWith(
                  color: context.runninPalette.text.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barras de carga (km projetados) por semana, conforme o PNG da periodização.
/// A semana ATUAL fica em cyan sólido; as demais em cyan suave. Label de km
/// em cima e "S{n}" embaixo.
class _CargaBars extends StatelessWidget {
  final List<PlanWeek> weeks;
  final int currentWeekIndex;
  const _CargaBars({required this.weeks, required this.currentWeekIndex});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    if (weeks.isEmpty) return const SizedBox.shrink();
    final loads = weeks
        .map((w) =>
            w.projectedLoadKm ??
            w.sessions.fold<double>(0, (s, x) => s + x.distanceKm))
        .toList();
    final maxLoad = loads.fold<double>(1, (m, l) => l > m ? l : m);
    const maxBarH = 90.0;
    const minBarH = 18.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(weeks.length, (i) {
        final w = weeks[i];
        final load = loads[i];
        final isCurrent = i == currentWeekIndex;
        final barColor =
            isCurrent ? palette.primary : palette.primary.withValues(alpha: 0.3);
        final h = minBarH + (load / maxLoad) * (maxBarH - minBarH);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < weeks.length - 1 ? 10 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${load.toStringAsFixed(0)}K',
                  style: type.labelCaps.copyWith(
                    color: isCurrent ? palette.primary : palette.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: h, color: barColor),
                const SizedBox(height: 6),
                Text(
                  'S${w.weekNumber}',
                  style: type.labelCaps.copyWith(
                    color: isCurrent ? palette.primary : palette.muted,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _WeekChip extends StatelessWidget {
  final int weekNumber;
  final bool selected;
  /// true pra a semana corrente do plano (calculada por civil-week). Quando
  /// não selecionada, renderiza outline em palette.primary pra indicar
  /// "você está aqui" mesmo navegando pra outra semana.
  final bool isCurrent;
  /// true quando essa semana contém a meta (última do plano RACE).
  /// Renderiza label "META" abaixo do número.
  final bool isTargetWeek;
  final VoidCallback onTap;

  const _WeekChip({
    required this.weekNumber,
    required this.selected,
    required this.onTap,
    this.isCurrent = false,
    this.isTargetWeek = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final Color borderColor;
    final double borderWidth;
    if (selected) {
      borderColor = palette.primary;
      borderWidth = 1.041;
    } else if (isCurrent) {
      borderColor = palette.primary;
      borderWidth = 1.5;
    } else {
      borderColor = palette.border;
      borderWidth = 1.041;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'S$weekNumber',
              style: context.runninType.labelCaps.copyWith(
                fontSize: 11,
                color: selected ? palette.background : palette.muted,
              ),
            ),
            if (isTargetWeek) ...[
              const SizedBox(height: 2),
              Text(
                'META',
                style: context.runninType.labelCaps.copyWith(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: selected ? palette.background : palette.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  // Mantém na assinatura por compat com call sites; ignorado no render.
  final String indexLabel;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.indexLabel,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.runninType.displayMd),
        const SizedBox(height: 6),
        Text(subtitle, style: context.runninType.bodySm),
      ],
    );
  }
}
class _WeeklySessionRow extends StatelessWidget {
  final int weekNumber;
  final int dayOfWeek;
  final DateTime dayDate;
  final PlanSession? session;
  final bool isToday;
  final bool isPast;
  /// true quando a semana selecionada está em skeleton (detailLevel != 'full').
  /// Renderiza cadeado + tap abre dialog em vez de navegar pro day_detail.
  final bool isLocked;
  final Plan plan;

  const _WeeklySessionRow({
    required this.weekNumber,
    required this.dayOfWeek,
    required this.dayDate,
    required this.session,
    required this.isToday,
    required this.isPast,
    required this.plan,
    this.isLocked = false,
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
    final hasPlanned = !isRest;
    // "Concluído" vem da corrida real vinculada (executedRunId), não da data.
    final isExecuted = hasPlanned && (session?.isExecuted ?? false);
    final missedPast = hasPlanned && isPast && !isExecuted;
    final dd = dayDate.day.toString().padLeft(2, '0');
    final mm = dayDate.month.toString().padLeft(2, '0');
    final dayShort = _dayNames[dayOfWeek].substring(0, 3).toUpperCase();

    // 4 estados visualmente distintos:
    //  HOJE              → border PRIMARY grossa + bg primary 0.18 + ícone alvo
    //  CORRIDA FUTURA    → border SECONDARY 1.5 + bg surface + ícone correr
    //  CORRIDA PASSADA   → bg primary forte + label OK em background color
    //  DESCANSO          → border DASHED muted + bg surface + ícone moon
    //  PASSADO/DESCANSO  → tudo cinza apagado
    final Color cellBg;
    final Color cellFg;
    final Color rowBg;
    final Color rowBorder;
    final double rowBorderWidth;
    final IconData? statusIcon;
    final String cellLabel;
    if (isToday) {
      cellBg = palette.primary;
      cellFg = palette.background;
      cellLabel = 'HOJE';
      rowBg = palette.primary.withValues(alpha: 0.10);
      rowBorder = palette.primary;
      rowBorderWidth = 1.5;
      statusIcon = hasPlanned ? Icons.gps_fixed : Icons.bedtime_outlined;
    } else if (isExecuted) {
      // sessão concluída (corrida real vinculada)
      cellBg = palette.primary.withValues(alpha: 0.85);
      cellFg = palette.background;
      cellLabel = 'OK';
      rowBg = palette.surface;
      rowBorder = palette.primary.withValues(alpha: 0.30);
      rowBorderWidth = 1.0;
      statusIcon = Icons.check_circle_outline;
    } else if (missedPast) {
      // sessão planejada que passou sem ser feita
      cellBg = palette.surfaceAlt;
      cellFg = palette.muted.withValues(alpha: 0.7);
      cellLabel = dayShort;
      rowBg = palette.surface.withValues(alpha: 0.7);
      rowBorder = palette.warning.withValues(alpha: 0.3);
      rowBorderWidth = 1.0;
      statusIcon = Icons.remove_circle_outline;
    } else if (isPast) {
      // descanso passado
      cellBg = palette.surfaceAlt;
      cellFg = palette.muted.withValues(alpha: 0.5);
      cellLabel = dayShort;
      rowBg = palette.surface.withValues(alpha: 0.6);
      rowBorder = palette.border.withValues(alpha: 0.5);
      rowBorderWidth = 1.0;
      statusIcon = null;
    } else if (hasPlanned) {
      // corrida futura
      cellBg = palette.surface;
      cellFg = palette.secondary;
      cellLabel = dayShort;
      rowBg = palette.surface;
      rowBorder = palette.secondary.withValues(alpha: 0.55);
      rowBorderWidth = 1.3;
      statusIcon = Icons.directions_run;
    } else {
      // descanso futuro
      cellBg = palette.surfaceAlt.withValues(alpha: 0.5);
      cellFg = palette.muted;
      cellLabel = dayShort;
      rowBg = palette.surface.withValues(alpha: 0.5);
      rowBorder = palette.border;
      rowBorderWidth = 1.0;
      statusIcon = Icons.nightlight_outlined;
    }

    return InkWell(
      onTap: isLocked
          ? () => _showCheckpointLockDialog(context, plan, weekNumber)
          : () => context.push('/training/day/$weekNumber/$dayOfWeek'),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border.all(color: rowBorder, width: rowBorderWidth),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            color: cellBg,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cellLabel,
                  style: context.runninType.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: isToday || isExecuted
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: cellFg,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dd/$mm',
                  style: context.runninType.bodyXs.copyWith(
                    fontSize: 9,
                    color: cellFg.withValues(alpha: 0.85),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (statusIcon != null) ...[
                      Icon(statusIcon, size: 14, color: cellFg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _dayNames[dayOfWeek],
                      style: context.runninType.displaySm.copyWith(
                        fontSize: 18,
                        color: isPast && !isToday ? palette.muted : palette.text,
                      ),
                    ),
                    if (isExecuted || (isPast && !isToday)) ...[
                      const SizedBox(width: 8),
                      Text(
                        isExecuted
                            ? '· concluído'
                            : (missedPast ? '· perdido' : '· passado'),
                        style: context.runninType.bodyXs.copyWith(
                          fontSize: 10,
                          color: palette.muted.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Só o tipo da sessão (sem hidratação/nutrição/duração — vide PNG).
                // Sessão já executada → tipo aparece SOBRETACHADO (riscado).
                Text(
                  isRest ? 'Descanso' : session!.type,
                  style: context.runninType.bodyMd.copyWith(
                    color: palette.muted,
                    decoration:
                        isExecuted ? TextDecoration.lineThrough : null,
                    decorationColor: palette.muted,
                  ),
                ),
              ],
            ),
          ),
          if (!isRest)
            // Quando a semana é skeleton (locked), o bloco distância/pace
            // fica esmaecido e ganha um cadeado discreto à direita. Comunica
            // visualmente que esses valores ainda são "esqueleto" e abrem o
            // dialog ao invés do day_detail.
            Row(
              children: [
                Opacity(
                  opacity: isLocked ? 0.45 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _distanceLabel(session!),
                        style: context.runninType.dataXs.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: palette.secondary,
                        ),
                      ),
                      if (session!.targetPace != null)
                        Text(
                          '${session!.targetPace!}/km',
                          style: context.runninType.bodySm.copyWith(
                            color: palette.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.lock_outline, size: 16, color: palette.muted),
                ],
              ],
            ),
        ],
      ),
      ),
    );
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
  final Plan plan;
  final PlanWeek week;
  final String status; // COMPLETA | PARCIAL | ATUAL | PRÓXIMA
  final Color statusColor;
  /// Disparado quando o user clica num card NÃO bloqueado (skeleton trata
  /// tap internamente com dialog de checkpoint).
  final VoidCallback onTap;

  const _MonthlyWeekCard({
    required this.plan,
    required this.week,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    // Conteúdo didático vem do BE (blockName/objective/projectedLoadKm/targets).
    // Nome da semana: usa o MESMO label canônico do Plano Base.
    final blockName = planWeekLabel(week);
    final objective = (week.objective?.trim().isNotEmpty ?? false)
        ? week.objective!.trim()
        : null;
    final loadKm = week.projectedLoadKm ??
        week.sessions.fold<double>(0, (s, x) => s + x.distanceKm);
    // Resumo por TIPO (ex.: "3 x EASY RUN") em vez de listar dia a dia.
    final byType = <String, int>{};
    for (final s in week.sessions) {
      final t = s.type.trim().toUpperCase();
      if (t.isEmpty) continue;
      byType[t] = (byType[t] ?? 0) + 1;
    }
    final restCount =
        7 - week.sessions.map((s) => s.dayOfWeek).toSet().length;
    final summaryLines = <String>[
      for (final e in (byType.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value))))
        '${e.value} x ${e.key}',
      if (restCount > 0) '$restCount x DESCANSO',
    ];
    final isCompleted = status == 'COMPLETA';
    final isCurrent = status == 'ATUAL';
    final isLocked = week.isSkeleton;

    // O bloco de conteúdo didático (objetivo + targets + resumo por tipo)
    // fica esmaecido quando o card está locked — comunica visualmente que
    // não tem informação real ali ainda.
    final detailedContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (objective != null) ...[
          const SizedBox(height: 8),
          Text(
            objective,
            style: context.runninType.bodySm.copyWith(
              color: palette.text.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
        ],
        if (week.targets.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...week.targets.map((t) => _BulletLine(text: t)),
        ],
        if (summaryLines.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...summaryLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: context.runninType.bodyXs.copyWith(color: palette.muted),
              ),
            ),
          ),
        ],
      ],
    );

    return InkWell(
      onTap: isLocked
          ? () => _showCheckpointLockDialog(context, plan, week.weekNumber)
          : onTap,
      child: AppPanel(
        margin: const EdgeInsets.only(bottom: 8),
        // Semana ATUAL em destaque: borda cyan + fundo levemente tingido.
        color: isCurrent ? palette.primary.withValues(alpha: 0.06) : null,
        borderColor: isCurrent ? palette.primary : palette.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        color: palette.primary.withValues(alpha: 0.15),
                        child: Text(
                          'SEM ${week.weekNumber}',
                          style: context.runninType.labelCaps.copyWith(
                            color: palette.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Text(
                        blockName,
                        style: context.runninType.bodyMd.copyWith(
                          fontWeight: FontWeight.w500,
                          color: palette.text,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isLocked) _LockedChip(),
                      if (isCompleted)
                        Icon(Icons.check_circle,
                            size: 15, color: palette.primary),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${loadKm.toStringAsFixed(0)}K',
                      style: context.runninType.dataMd.copyWith(
                        fontWeight: FontWeight.w600,
                        // Distância em CYAN na semana atual; laranja nas demais.
                        color: isCurrent ? palette.primary : palette.secondary,
                      ),
                    ),
                    Text(
                      status,
                      style: context.runninType.labelCaps.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // No locked, o bloco de detalhe vira fantasma (opacity 0.4) — não
            // engana o user achando que aquilo é o conteúdo final, mas mantém
            // a estrutura da grade.
            isLocked
                ? Opacity(opacity: 0.4, child: detailedContent)
                : detailedContent,
          ],
        ),
      ),
    );
  }

}

/// Chip "BLOQUEADA" com ícone de cadeado — usado no header do
/// _MonthlyWeekCard quando week.isSkeleton (substitui o badge discreto
/// anterior por uma sinalização visual mais forte).
class _LockedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.16),
        border: Border.all(color: palette.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 11, color: palette.primary),
          const SizedBox(width: 4),
          Text(
            'BLOQUEADA',
            style: context.runninType.labelCaps.copyWith(
              color: palette.primary,
              letterSpacing: 1.0,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bullet "▸ texto" pros objetivos da semana na periodização.
class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine({required this.text});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('▸ ',
              style: context.runninType.bodySm
                  .copyWith(color: palette.primary, fontSize: 12.5)),
          Expanded(
            child: Text(
              text,
              style: context.runninType.bodySm.copyWith(
                color: palette.text.withValues(alpha: 0.82),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge "ESQUELETO" pras semanas ainda não detalhadas (liberadas no
/// checkpoint da semana anterior).
/// Aviso na visão semanal quando a semana ainda é esqueleto: volume e pace
/// já estão definidos; nutrição, hidratação e roteiro km-a-km são liberados
/// no checkpoint da semana anterior.
class _SkeletonWeekNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_clock_outlined, size: 16, color: palette.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Volume e pace já definidos. O detalhe completo (roteiro, nutrição, '
              'hidratação) é liberado no checkpoint da semana anterior — assim o '
              'coach ajusta pela sua evolução real.',
              style: context.runninType.bodyXs.copyWith(
                color: palette.muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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

int _currentPlanWeekIndex(Plan plan) => plan.currentWeekIndex();

String _buildWeekHeadline(PlanWeek? week) {
  if (week == null) return 'Semana sem sessoes planejadas';
  final totalKm = week.sessions.fold<double>(
    0,
    (sum, session) => sum + session.distanceKm,
  );
  return 'Semana ${week.weekNumber} · ${week.sessions.length} sessoes · ${totalKm.toStringAsFixed(1)} km';
}

/// Summary per-week — prioriza narrative gerada pela IA (personalizada pelo
/// perfil do user) se disponível; senão fallback determinístico com volume +
/// sessão-chave + foco.
String _buildWeekSummary(PlanWeek? week) {
  if (week == null || week.sessions.isEmpty) {
    return 'Sem sessões nesta semana — descanso ativo recomendado.';
  }
  // Se LLM já preencheu narrativa personalizada, usa essa
  if (week.narrative != null && week.narrative!.trim().isNotEmpty) {
    return week.narrative!.trim();
  }
  final ordered = [...week.sessions]
    ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
  final totalKm = ordered.fold<double>(0, (s, x) => s + x.distanceKm);
  // Sessão-chave: a mais longa (geralmente o long run da semana).
  final keySession = [...ordered]
    ..sort((a, b) => b.distanceKm.compareTo(a.distanceKm));
  final key = keySession.first;
  final focus = _deriveWeekFocus(week).toLowerCase();
  final restDays = 7 - ordered.length;
  // Conta tipos pra mensagem específica.
  final typeCounts = <String, int>{};
  for (final s in ordered) {
    typeCounts.update(s.type, (v) => v + 1, ifAbsent: () => 1);
  }
  final dominantType = typeCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final dominant = dominantType.first.key;

  return 'Semana ${week.weekNumber} · foco em $focus. '
      'Volume: ${totalKm.toStringAsFixed(1)}km em ${ordered.length} sessões + '
      '$restDays descanso. Sessão-chave: ${key.type} de ${key.distanceKm.toStringAsFixed(1)}km '
      'na ${_dayNamePt(key.dayOfWeek)}. Predomínio: $dominant.';
}

String _dayNamePt(int d) {
  const names = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  return names[d.clamp(1, 7)];
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

String _formatDuration(int durationS) {
  final minutes = durationS ~/ 60;
  final seconds = durationS % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Banner mostrado quando o plano ativo foi marcado como completed pelo
/// server (mesocycleEndDate passou). Convida o user a ver o relatório
/// final E/OU gerar um novo plano. O resto da tela cai em _EmptyState.
class _PlanCompletedBanner extends StatelessWidget {
  final String planId;
  final VoidCallback onSeeReport;
  final VoidCallback onNewPlan;
  const _PlanCompletedBanner({
    required this.planId,
    required this.onSeeReport,
    required this.onNewPlan,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.10),
        border: Border.all(color: palette.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: palette.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'PLANO CONCLUÍDO!',
                style: context.runninType.labelMd.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Seu mesociclo terminou. Veja o relatório com o resumo (prazo inicial × real, ajustes feitos no caminho) ou gere um novo plano.',
            style: context.runninType.bodySm.copyWith(
              color: palette.text,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSeeReport,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.primary, width: 1.041),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    minimumSize: const Size(0, 42),
                  ),
                  child: Text(
                    'VER RELATÓRIO',
                    style: context.runninType.labelMd.copyWith(
                      color: palette.primary,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onNewPlan,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text('GERAR NOVO PLANO'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Data em que o checkpoint da semana M-1 deve rodar (Sunday cron + user
/// aceitar a proposta) e promover a semana [weekNumber] de skeleton pra full.
/// Regra: cada checkpoint enriquece as 2 próximas semanas (ver
/// server/checkpoint-shared.ts:enrichTwoTier), então a semana M só é
/// detalhada no final da semana M-1.
/// Retorna label tipo "segunda, 12/07". Se já passou, retorna
/// "no próximo checkpoint" (raro — server propaga rápido).
///
/// NOTA: weekday em PT-BR é computado manualmente em vez de via
/// DateFormat('EEEE', 'pt_BR'), porque `initializeDateFormatting('pt_BR')`
/// não é chamado no boot — usar locale custom no DateFormat lança
/// LocaleDataException e quebra o dialog (tela branca).
String _checkpointUnlockLabel(Plan plan, int weekNumber) {
  final startDate = plan.effectiveStartDate;
  // M=1: nunca skeleton, mas tratamos como "hoje" se chegar aqui.
  // M=2: nunca skeleton (criado full), idem.
  // M>=3: liberado em startDate + (M-1)*7 - 1 dias = último dia da semana M-1.
  final unlockDate = startDate.add(Duration(days: (weekNumber - 1) * 7 - 1));
  final today = DateTime.now();
  final todayDateOnly = DateTime(today.year, today.month, today.day);
  if (unlockDate.isBefore(todayDateOnly)) return 'no próximo checkpoint';
  const weekdays = <String>[
    '', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo',
  ];
  final wd = weekdays[unlockDate.weekday];
  final dd = unlockDate.day.toString().padLeft(2, '0');
  final mm = unlockDate.month.toString().padLeft(2, '0');
  return 'em $wd, $dd/$mm';
}

/// Diálogo único compartilhado por MENSAL e SEMANAL quando o user toca numa
/// semana / dia skeleton. Explica a regra D+15 e mostra a data prevista de
/// liberação do detalhe.
Future<void> _showCheckpointLockDialog(
  BuildContext context,
  Plan plan,
  int weekNumber,
) {
  final palette = context.runninPalette;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surface,
      title: Text('Semana $weekNumber · bloqueada'),
      content: Text(
        'O coach detalha as duas próximas semanas a cada checkpoint, usando '
        'seus números reais.\n\n'
        'O detalhe completo desta semana é liberado '
        '${_checkpointUnlockLabel(plan, weekNumber)} — antes disso, ele só '
        'conhece o esqueleto (tipo de sessão, distância e pace alvo).',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('ENTENDI'),
        ),
      ],
    ),
  );
}
