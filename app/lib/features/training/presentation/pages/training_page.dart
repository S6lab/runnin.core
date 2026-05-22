import 'dart:async';

import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:runnin/features/coach/data/datasources/coach_report_remote_datasource.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/data/weekly_report_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/features/training/domain/week_phase_label.dart';
import 'package:runnin/features/training/domain/entities/weekly_report.dart';
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


  Future<List<WeeklyReport>> _loadWeeklyReports() async {
    try {
      return await _weeklyReportDs.getWeeklyReports();
    } catch (_) {
      return [];
    }
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

      // Gate centralizado no billing plan: gerar plano é feature `generatePlan`
      // (Pro). Freemium vai pro paywall.
      await subscriptionController.refresh();
      if (!subscriptionController.has('generatePlan')) {
        if (mounted) {
          setState(() => _generating = false);
          context.push('/paywall?next=/training');
        }
        return;
      }

      String planId;
      try {
        planId = await _ds.generatePlan(
          goal: goal,
          level: level,
          frequency: profile.frequency,
        );
      } on DioException catch (e) {
        // Backend pode rejeitar com 403 (premium_required) se UI gate falhar
        // por algum motivo (cache profile, race condition). Redireciona pro paywall.
        if (e.response?.statusCode == 403) {
          if (mounted) {
            setState(() => _generating = false);
            context.push('/paywall?next=/training');
          }
          return;
        }
        // Server rejeita se já existe plano ativo. Pergunta antes de overwrite.
        if (e.response?.statusCode == 409) {
          if (!mounted) return;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Substituir plano atual?'),
              content: const Text(
                'Você já tem um plano ativo. Gerar um novo apaga o atual e o histórico de revisões. '
                'Para ajustes pontuais, prefira a "Revisão semanal" do plano.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCELAR')),
                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('SUBSTITUIR')),
              ],
            ),
          );
          if (confirmed != true) {
            if (mounted) setState(() => _generating = false);
            return;
          }
          try {
            planId = await _ds.generatePlan(
              goal: goal,
              level: level,
              frequency: profile.frequency,
              confirmOverwrite: true,
            );
          } on DioException catch (e2) {
            // Server enforça 1 substituição/semana. Mensagem amigável com
            // data de quando libera novamente.
            // Error middleware embrulha em { error: { code, message, availableAt } }
            final body = e2.response?.data;
            final errMap = body is Map ? body['error'] : null;
            final code = errMap is Map ? errMap['code'] as String? : null;
            if (e2.response?.statusCode == 403 && code == 'COOLDOWN_ACTIVE') {
              if (!mounted) return;
              final availableAt = (errMap as Map)['availableAt'] as String?;
              await _showCooldownDialog(availableAt);
              if (mounted) setState(() => _generating = false);
              return;
            }
            rethrow;
          }
        } else {
          rethrow;
        }
      }
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

  Future<void> _showCooldownDialog(String? availableAtIso) async {
    final palette = context.runninPalette;
    String availableLine;
    if (availableAtIso != null) {
      try {
        final dt = DateTime.parse(availableAtIso).toLocal();
        final dd = dt.day.toString().padLeft(2, '0');
        final mm = dt.month.toString().padLeft(2, '0');
        final hh = dt.hour.toString().padLeft(2, '0');
        final mi = dt.minute.toString().padLeft(2, '0');
        final daysLeft = dt.difference(DateTime.now()).inDays;
        availableLine = daysLeft > 0
            ? 'Próximo plano disponível em $daysLeft dia${daysLeft == 1 ? '' : 's'} ($dd/$mm às $hh:$mi).'
            : 'Próximo plano disponível em $dd/$mm às $hh:$mi.';
      } catch (_) {
        availableLine = 'Aguarde até a próxima semana pra gerar outro plano.';
      }
    } else {
      availableLine = 'Aguarde até a próxima semana pra gerar outro plano.';
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: const Text('Limite de geração atingido'),
        content: Text(
          'Na primeira semana você pode gerar 2 planos (caso queira refazer). '
          'Depois, é 1 novo plano por semana. Pra ajustes pontuais (mais carga, '
          'troca de dias, etc.), use a "Revisão semanal" ou o checkpoint do plano '
          'atual.\n\n$availableLine',
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
      return _EmptyState(generating: _generating, onGenerate: _generate);
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
      return _PlanFailedState(generating: _generating, onGenerate: _generate);
    }

    return _TrainingWorkspace(
      plan: _plan!,
      profile: _profile,
      reports: _reports,
      weeklyReports: _weeklyReports,
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
        if (week?.isSkeleton ?? false) ...[
          _SkeletonWeekNotice(),
          const SizedBox(height: 12),
        ],
        ...() {
          // Datas reais por sessão: cada semana começa na segunda anterior
          // (ou em plan.createdAt se foi gerado numa segunda). Week 1 alinha
          // com a semana corrente da geração; weeks subsequentes somam +7 dias.
          final today = DateTime.now();
          final todayDateOnly = DateTime(today.year, today.month, today.day);
          final planCreated = DateTime.tryParse(plan.createdAt) ?? today;
          final week1Monday = planCreated.subtract(
            Duration(days: (planCreated.weekday - 1) % 7),
          );
          final weekStartMonday = DateTime(
            week1Monday.year,
            week1Monday.month,
            week1Monday.day,
          ).add(Duration(days: selectedWeek * 7));
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
            );
          });
        }(),
        const SizedBox(height: 12),
        _CheckpointEntry(
          planId: plan.id,
          weekNumber: selectedWeek + 1,
        ),
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

/// Entry compacta pro checkpoint semanal. Tap → /training/checkpoint/:planId/:weekNumber.
/// Não bloqueia a UI se falhar — apenas omite o card.
class _CheckpointEntry extends StatelessWidget {
  final String planId;
  final int weekNumber;
  const _CheckpointEntry({required this.planId, required this.weekNumber});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: () => context.push('/training/checkpoint/$planId/$weekNumber'),
      child: AppPanel(
        borderColor: palette.primary.withValues(alpha: 0.55),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              color: palette.primary.withValues(alpha: 0.18),
              child: Text(
                'CHECKPOINT',
                style: context.runninType.labelCaps.copyWith(
                  color: palette.primary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Fim de SEM $weekNumber · ajustar plano com base na sua semana',
                style: context.runninType.bodySm.copyWith(
                  color: palette.text,
                  fontSize: 12.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: palette.muted, size: 18),
          ],
        ),
      ),
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
        // Mostra só as 4 PRIMEIRAS semanas do plano (o resto se ajusta).
        ...plan.weeks.take(4).toList().asMap().entries.map((entry) {
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
            week: week,
            status: status,
            statusColor: statusColor,
            onTap: () => onWeekTap(week.weekNumber),
          );
        }),
        const SizedBox(height: 8),
        // Resumo de carga (km projetados) das 4 primeiras semanas, em barras.
        _CargaBars(
          weeks: plan.weeks.take(4).toList(),
          currentWeekIndex: _currentPlanWeekIndex(plan),
        ),
        const SizedBox(height: 16),
        // Box estática do coach explicando o recorte das 4 semanas.
        FigmaCoachAIBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FigmaCoachAIBreadcrumb(action: 'PERIODIZAÇÃO'),
              const SizedBox(height: 10),
              Text(
                'Aqui aparecem só as 4 primeiras semanas do plano. O plano vai '
                'se ajustando conforme o seu andamento e a sua performance — por '
                'isso as semanas seguintes não são fixas. O resumo detalhado, '
                'semana a semana, está no Plano Base.',
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? palette.primary : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Text(
          'S$weekNumber',
          style: context.runninType.labelCaps.copyWith(
            fontSize: 11,
            color: selected ? palette.background : palette.muted,
          ),
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

  const _WeeklySessionRow({
    required this.weekNumber,
    required this.dayOfWeek,
    required this.dayDate,
    required this.session,
    required this.isToday,
    required this.isPast,
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
      onTap: () => context.push('/training/day/$weekNumber/$dayOfWeek'),
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
            Column(
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
  final PlanWeek week;
  final String status; // COMPLETA | PARCIAL | ATUAL | PRÓXIMA
  final Color statusColor;
  final VoidCallback onTap;

  const _MonthlyWeekCard({
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

    return InkWell(
      onTap: onTap,
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
                      if (week.isSkeleton)
                        _SkeletonBadge(),
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
                    style: context.runninType.bodyXs
                        .copyWith(color: palette.muted),
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
class _SkeletonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: palette.muted.withValues(alpha: 0.5)),
      ),
      child: Text(
        'DETALHE NO CHECKPOINT',
        style: context.runninType.labelCaps.copyWith(
          fontSize: 8.5,
          color: palette.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

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
