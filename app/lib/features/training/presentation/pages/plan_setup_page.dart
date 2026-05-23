import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/history/data/stats_remote_datasource.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_start_date.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/presentation/steps/step_current_load.dart';
import 'package:runnin/features/training/presentation/steps/step_days.dart';
import 'package:runnin/features/training/presentation/steps/step_goal_v2.dart';
import 'package:runnin/features/training/presentation/steps/step_level_v2.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Jornada redesenhada de criação do plano (/training/criar-plano). 6 telas:
/// intro "plano vivo" → 5 níveis (com smart pre-fill) → 5 metas (com prazo
/// médio) → dias + freq → pace + carga → quando começar. Submit faz gate
/// premium, patchMe(level/goal/freq/availableDays), gera o plano e cai em
/// /plan-loading. 409 (overwrite) e cooldown são tratados com diálogos.
class PlanSetupPage extends StatefulWidget {
  const PlanSetupPage({super.key});

  @override
  State<PlanSetupPage> createState() => _PlanSetupPageState();
}

class _PlanSetupPageState extends State<PlanSetupPage> {
  final _userDs = UserRemoteDatasource();
  final _planDs = PlanRemoteDatasource();
  final _statsDs = StatsRemoteDatasource();

  static const _totalSteps = 6;
  int _step = 0;

  // Estado da jornada
  PlanLevelChoice? _level;
  PlanLevelChoice? _suggestedLevel;
  PlanGoalChoice? _goal;
  Set<int> _availableDays = {1, 3, 5, 6}; // seg, qua, sex, sab (default razoável)
  int _frequency = 4;
  final _paceCtrl = TextEditingController();
  final _weeklyKmCtrl = TextEditingController();
  String? _historyHint;
  bool _skipCurrentLoad = false;
  String _startChoice = 'today';
  DateTime _customDate = OnboardingStartDateStep.today();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistoryAndSuggest();
  }

  @override
  void dispose() {
    _paceCtrl.dispose();
    _weeklyKmCtrl.dispose();
    super.dispose();
  }

  /// Lê /stats/breakdown do último mês pra (1) sugerir nível na tela 02 e
  /// (2) prefill pace/carga atual na tela 05. Falha silenciosa — sem histórico
  /// a jornada segue funcionando com campos vazios.
  Future<void> _loadHistoryAndSuggest() async {
    try {
      final breakdown = await _statsDs.getBreakdown('month');
      final stats = breakdown.stats;
      final paceSec = _paceLabelToSec(stats.avgPace);
      final suggestion = suggestLevelFromStats(LevelSuggestionInput(
        runsLast30d: stats.runs,
        totalKmLast30d: stats.totalDistanceKm,
        avgPaceSec: paceSec,
      ));
      if (!mounted) return;
      setState(() {
        _suggestedLevel = suggestion;
        _level ??= suggestion;
        if (stats.runs > 0) {
          final weeklyKm = stats.totalDistanceKm / 4.345;
          _historyHint =
              'Últimas 4 semanas: ${weeklyKm.toStringAsFixed(1)} km/sem · pace ${stats.avgPace ?? '—'}';
          if (_paceCtrl.text.isEmpty && stats.avgPace != null) {
            _paceCtrl.text = stats.avgPace!;
          }
          if (_weeklyKmCtrl.text.isEmpty) {
            _weeklyKmCtrl.text = weeklyKm.toStringAsFixed(0);
          }
        }
      });
    } catch (_) {
      // Sem histórico ou erro — segue silencioso.
    }
  }

  static int? _paceLabelToSec(String? label) {
    if (label == null || label.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(label);
    if (m == null) return null;
    final mm = int.tryParse(m.group(1)!) ?? 0;
    final ss = int.tryParse(m.group(2)!) ?? 0;
    return mm * 60 + ss;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          FigmaOnboardingTopProgressBar(total: _totalSteps, currentIndex: _step),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragEnd: _handleSwipe,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildStep(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildNav(context),
                    const SizedBox(height: 12),
                    FigmaOnboardingPageIndicator(
                      total: _totalSteps,
                      currentIndex: _step,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = context.runninPalette;
    final canGoBack = _step > 0;
    return Row(
      children: [
        OutlinedButton(
          onPressed: _submitting
              ? null
              : () {
                  if (canGoBack) {
                    setState(() => _step--);
                  } else {
                    context.pop();
                  }
                },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(86, 38),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(canGoBack ? '< VOLTAR' : '< SAIR'),
        ),
        const Spacer(),
        Text('RUNIN', style: context.runninType.labelMd),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          color: palette.primary,
          child: Text(
            '.AI',
            style: context.runninType.labelMd.copyWith(
              color: palette.background,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 66),
      ],
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return const OnboardingPrepStep();
      case 1:
        return PlanStepLevelV2(
          selected: _level,
          suggested: _suggestedLevel,
          onSelect: (v) => setState(() => _level = v),
        );
      case 2:
        return PlanStepGoalV2(
          selected: _goal,
          onSelect: (v) => setState(() => _goal = v),
        );
      case 3:
        return PlanStepDays(
          availableDays: _availableDays,
          frequency: _frequency,
          onDaysChange: (days) => setState(() {
            _availableDays = days;
            if (days.isNotEmpty && _frequency > days.length) {
              _frequency = days.length;
            }
          }),
          onFreqChange: (f) => setState(() => _frequency = f),
        );
      case 4:
        return PlanStepCurrentLoad(
          paceController: _paceCtrl,
          weeklyKmController: _weeklyKmCtrl,
          hintFromHistory: _historyHint,
          skipped: _skipCurrentLoad,
          onSkip: () => setState(() => _skipCurrentLoad = !_skipCurrentLoad),
        );
      case 5:
        return OnboardingStartDateStep(
          selected: _startChoice,
          customDate: _customDate,
          onSelect: (choice, date) => setState(() {
            _startChoice = choice;
            _customDate = date;
          }),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNav(BuildContext context) {
    final palette = context.runninPalette;
    final isLast = _step == _totalSteps - 1;
    final label = isLast ? 'CRIAR PLANO' : 'CONTINUAR';
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _canProceed()
                ? (isLast ? _submit : () => setState(() => _step++))
                : null,
            child: _submitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.background,
                    ),
                  )
                : Text('$label /'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: context.runninType.bodySm.copyWith(color: palette.error),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  bool _canProceed() {
    if (_submitting) return false;
    switch (_step) {
      case 1:
        return _level != null;
      case 2:
        return _goal != null;
      case 3:
        if (_availableDays.isEmpty) return false;
        return _frequency >= 1 && _frequency <= _availableDays.length;
      case 4:
        // Pace/carga é opcional via skip. Sem skip, exige pace válido OU vazio.
        if (_skipCurrentLoad) return true;
        if (_paceCtrl.text.isEmpty && _weeklyKmCtrl.text.isEmpty) return true;
        final paceOk =
            _paceCtrl.text.isEmpty || RegExp(r'^\d{1,2}:\d{2}$').hasMatch(_paceCtrl.text.trim());
        final kmOk =
            _weeklyKmCtrl.text.isEmpty || double.tryParse(_weeklyKmCtrl.text.trim()) != null;
        return paceOk && kmOk;
      default:
        return true;
    }
  }

  void _handleSwipe(DragEndDetails details) {
    if (_submitting) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300 && _step > 0) {
      setState(() => _step--);
    } else if (velocity < -300 && _step < _totalSteps - 1 && _canProceed()) {
      setState(() => _step++);
    }
  }

  String _startDateIso() {
    final d = _customDate;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_canProceed() || _submitting) return;
    setState(() {
      _error = null;
      _submitting = true;
    });

    // Gate premium: free cai no paywall e volta pra cá depois de assinar.
    await subscriptionController.refresh();
    if (!subscriptionController.has('generatePlan')) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.push('/paywall?next=/training/criar-plano');
      return;
    }

    final level = _level!;
    final goal = _goal!;
    final availableDays = (_availableDays.toList()..sort());
    final pace = _skipCurrentLoad ? null : _paceCtrl.text.trim();
    final weeklyKm = _skipCurrentLoad ? null : double.tryParse(_weeklyKmCtrl.text.trim());

    try {
      await _userDs.patchMe(
        level: level.backendLevel,
        goal: goal.backendValue,
        frequency: _frequency,
        availableDays: availableDays,
      );

      final startDate = _startChoice == 'today' ? null : _startDateIso();
      try {
        await _planDs.generatePlan(
          goal: goal.backendValue,
          level: level.backendLevel,
          frequency: _frequency,
          startDate: startDate,
          levelHint: level.levelHint,
          currentPaceMinKm: pace?.isEmpty == true ? null : pace,
          currentWeeklyKm: weeklyKm,
          availableDays: availableDays.isEmpty ? null : availableDays,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) {
          if (!mounted) return;
          setState(() => _submitting = false);
          context.push('/paywall?next=/training/criar-plano');
          return;
        }
        if (e.response?.statusCode == 409) {
          final confirmed = await _confirmOverwrite();
          if (confirmed != true) {
            if (mounted) setState(() => _submitting = false);
            return;
          }
          try {
            await _planDs.generatePlan(
              goal: goal.backendValue,
              level: level.backendLevel,
              frequency: _frequency,
              startDate: startDate,
              confirmOverwrite: true,
              levelHint: level.levelHint,
              currentPaceMinKm: pace?.isEmpty == true ? null : pace,
              currentWeeklyKm: weeklyKm,
              availableDays: availableDays.isEmpty ? null : availableDays,
            );
          } on DioException catch (e2) {
            final body = e2.response?.data;
            final errMap = body is Map ? body['error'] : null;
            final code = errMap is Map ? errMap['code'] as String? : null;
            if (e2.response?.statusCode == 403 && code == 'COOLDOWN_ACTIVE') {
              final availableAt = (errMap as Map)['availableAt'] as String?;
              await _showCooldownDialog(availableAt);
              if (mounted) setState(() => _submitting = false);
              return;
            }
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      final qp = startDate == null ? '' : '?startDate=$startDate';
      context.go('/plan-loading$qp');
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error =
              'Não consegui gerar seu plano agora. Confira sua conexão e tente de novo.';
        });
      }
    }
  }

  Future<bool?> _confirmOverwrite() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Substituir plano atual?'),
        content: const Text(
          'Você já tem um plano ativo. Gerar um novo apaga o atual e o histórico de revisões. '
          'Lembre: seu plano já é vivo — toda semana o coach faz checkpoint e ajusta o caminho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('SUBSTITUIR'),
          ),
        ],
      ),
    );
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
          'Você pode gerar 1 plano novo por semana (caso queira recomeçar). '
          'Pra ajustes pontuais, use o checkpoint semanal do plano atual — '
          'o coach ajusta as 2 próximas semanas baseado no seu desempenho.\n\n$availableLine',
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
}
