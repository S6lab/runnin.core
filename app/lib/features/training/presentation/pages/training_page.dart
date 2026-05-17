import 'dart:async';

import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:runnin/features/coach/data/datasources/coach_report_remote_datasource.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/data/weekly_report_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/features/training/domain/entities/weekly_report.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/coach_narrative_card.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/features/training/presentation/pages/adjustments_history_page.dart';

enum _TrainingTab { plan, reports, adjustments }

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
  bool _loadingWeeklyReports = false;
  String? _selectedWeekStart;
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

      // Premium gate: gerar plano é feature Pro. Freemium vai pro paywall.
      if (!profile.isPro) {
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
        title: const Text('Limite semanal atingido'),
        content: Text(
          'No plano Pro você pode gerar um novo plano completo 1× por semana. '
          'Pra ajustes pontuais (mais carga, troca de dias, etc.), use a '
          '"Revisão semanal" do plano atual.\n\n$availableLine',
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
            Text(_error!, style: TextStyle(color: palette.muted)),
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
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
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
            _TrainingTab.reports => _ReportsTab(reports: reports, weeklyReports: weeklyReports),
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
            child: ElevatedButton.icon(
              onPressed: () => context.push('/training/plan-detail'),
              icon: Icon(Icons.menu_book_outlined, size: 16, color: palette.background),
              label: const Text('VER PLANO COMPLETO'),
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
            width: 1.041,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
                    fontWeight: FontWeight.w500,
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
          leftLabel: 'SEMANAL',
          rightLabel: 'MENSAL',
          leftSelected: planMode == _PlanMode.weekly,
          onLeftTap: () => onPlanModeChanged(_PlanMode.weekly),
          onRightTap: () => onPlanModeChanged(_PlanMode.monthly),
        ),
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
            width: 1.041,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
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
              dayOfWeek: day,
              dayDate: dayDate,
              session: sessionForDay,
              isToday: isToday,
              isPast: isPast,
            );
          });
        }(),
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

class _ReportsTab extends StatelessWidget {
  final List<_RunFeedback> reports;
  final List<WeeklyReport> weeklyReports;

  const _ReportsTab({required this.reports, required this.weeklyReports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty && weeklyReports.isEmpty) {
      return const _TabEmptyState(
        title: 'Nenhum feedback de IA ainda',
        body:
            'Os feedbacks reais aparecem aqui depois que voce conclui corridas com relatorio tecnico gerado pelo Coach.AI.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (weeklyReports.isNotEmpty) ...[
          _SectionTitle(
            title: 'RELATÓRIOS SEMANAIS',
            indexLabel: '02',
            subtitle:
                'Analises semanais de aderencia e desempenho',
          ),
          const SizedBox(height: 12),
          ...weeklyReports.map((report) => _WeeklyReportCard(report: report)),
        ],
        if (reports.isNotEmpty && weeklyReports.isNotEmpty) const SizedBox(height: 24),
        if (reports.isNotEmpty) ...[
          _SectionTitle(
            title: 'FEEDBACKS DA IA',
            indexLabel: '01',
            subtitle:
                'Analises tecnicas geradas a partir das suas corridas reais',
          ),
          const SizedBox(height: 12),
          ...reports.map((report) => _ReportCard(report: report)),
        ],
      ],
    );
  }
}

class _WeeklyReportCard extends StatelessWidget {
  final WeeklyReport report;

  const _WeeklyReportCard({required this.report});

  void _navigateToDetail(BuildContext context) {
    GoRouter.of(context).push('/training/report/${report.weekStart}');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      color: palette.surfaceAlt,
      borderColor: palette.primary.withValues(alpha: 0.35),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semana ${_formatWeekStart(report.weekStart)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${report.sessionsDone}/${report.sessionsPlanned} sessoes · ${report.totalKm.toStringAsFixed(1)}K',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _navigateToDetail(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${report.adherencePercent}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: palette.background,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeekStart(String weekStart) {
    try {
      final date = DateTime.parse(weekStart);
      return DateFormat('dd/MM').format(date);
    } catch (_) {
      return weekStart;
    }
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
            width: 1.041,
          ),
        ),
        child: Text(
          'S$weekNumber',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
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
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.runninType.displayMd),
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
  final DateTime dayDate;
  final PlanSession? session;
  final bool isToday;
  final bool isPast;

  const _WeeklySessionRow({
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
    final hadPastSession = isPast && hasPlanned;
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
    } else if (hadPastSession) {
      cellBg = palette.primary.withValues(alpha: 0.85);
      cellFg = palette.background;
      cellLabel = 'OK';
      rowBg = palette.surface;
      rowBorder = palette.primary.withValues(alpha: 0.30);
      rowBorderWidth = 1.0;
      statusIcon = Icons.check_circle_outline;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border.all(color: rowBorder, width: rowBorderWidth),
      ),
      padding: const EdgeInsets.all(12),
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday || hadPastSession
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: cellFg,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dd/$mm',
                  style: TextStyle(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isPast && !isToday ? palette.muted : palette.text,
                      ),
                    ),
                    if (isPast && !isToday) ...[
                      const SizedBox(width: 8),
                      Text(
                        hadPastSession ? '· feito' : '· passado',
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.muted.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isRest ? 'Descanso' : session!.type,
                  style: TextStyle(color: palette.muted),
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: palette.secondary,
                  ),
                ),
                if (session!.targetPace != null)
                  Text(
                    session!.targetPace!,
                    style: TextStyle(color: palette.muted),
                  ),
              ],
            ),
        ],
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
  final int weekNumber;
  final String focus;
  final String summary;
  final double totalDistance;
  final String status;
  final Color statusColor;

  const _MonthlyWeekCard({
    required this.weekNumber,
    required this.focus,
    required this.summary,
    required this.totalDistance,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: status == 'ATUAL'
          ? palette.primary.withValues(alpha: 0.45)
          : palette.border,
      child: Row(
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
                    fontWeight: FontWeight.w500,
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
                  fontWeight: FontWeight.w500,
                  color: palette.secondary,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.08,
                ),
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
                    fontWeight: FontWeight.w500,
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
                      fontWeight: FontWeight.w500,
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
            fontWeight: FontWeight.w500,
            color: palette.muted,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
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
