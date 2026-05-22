import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_frequency.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_goal.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_level.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_pace.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_start_date.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Jornada de criação do plano dentro de TREINO (/training/criar-plano).
///
/// Reúne as telas que antes ficavam no onboarding (nível, meta, dias/semana,
/// pace, quando começar) e dispara a geração no fim, com gate premium e
/// confirmação de substituição quando já existe plano ativo. O onboarding
/// agora só coleta dados pessoais (SEUS DADOS) e cai na Home.
///
/// Esta jornada será redesenhada depois; por ora ela MOVE as telas atuais pra
/// cá, funcionando. Ao concluir: patchMe(level/goal/frequency) → generatePlan →
/// /plan-loading (countdown visual; o plano já está sendo gerado no server).
class PlanSetupPage extends StatefulWidget {
  const PlanSetupPage({super.key});

  @override
  State<PlanSetupPage> createState() => _PlanSetupPageState();
}

class _PlanSetupPageState extends State<PlanSetupPage> {
  final _userDs = UserRemoteDatasource();
  final _planDs = PlanRemoteDatasource();

  // 0 intro · 1 nível · 2 meta · 3 dias · 4 pace · 5 quando começar
  static const _totalSteps = 6;
  int _step = 0;

  String _level = 'iniciante';
  String _goal = 'Completar 10K';
  int _frequency = 4;
  String? _pace;
  String _startChoice = 'today';
  DateTime _customDate = OnboardingStartDateStep.today();

  bool _submitting = false;
  String? _error;

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
        return OnboardingStepLevel(
          selected: _level,
          onSelect: (value) => setState(() => _level = value),
        );
      case 2:
        return OnboardingStepGoal(
          selectedGoal: _goal,
          onGoalSelect: (value) => setState(() => _goal = value),
        );
      case 3:
        return OnboardingStepFrequency(
          frequency: _frequency,
          onFreqChange: (value) => setState(() => _frequency = value),
        );
      case 4:
        return OnboardingStepPace(
          selected: _pace,
          onSelect: (value) => setState(() => _pace = value),
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
        return _level.isNotEmpty;
      case 2:
        return _goal.isNotEmpty;
      case 3:
        return _frequency >= 1 && _frequency <= 7;
      case 4:
        return _pace != null;
      default:
        return true;
    }
  }

  void _handleSwipe(DragEndDetails details) {
    if (_submitting) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300 && _step > 0) {
      setState(() => _step--);
    } else if (velocity < -300 &&
        _step < _totalSteps - 1 &&
        _canProceed()) {
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

    // Gate premium centralizado no billing plan (feature `generatePlan`).
    // Freemium cai no paywall e volta pra cá depois de assinar.
    await subscriptionController.refresh();
    if (!subscriptionController.has('generatePlan')) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.push('/paywall?next=/training/criar-plano');
      return;
    }

    try {
      await _userDs.patchMe(
        level: _level,
        goal: _goal,
        frequency: _frequency,
      );

      final startDate = _startChoice == 'today' ? null : _startDateIso();
      try {
        await _planDs.generatePlan(
          goal: _goal,
          level: _level,
          frequency: _frequency,
          startDate: startDate,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 403) {
          if (!mounted) return;
          setState(() => _submitting = false);
          context.push('/paywall?next=/training/criar-plano');
          return;
        }
        // Já existe plano ativo: confirma a substituição antes de sobrescrever.
        if (e.response?.statusCode == 409) {
          final confirmed = await _confirmOverwrite();
          if (confirmed != true) {
            if (mounted) setState(() => _submitting = false);
            return;
          }
          try {
            await _planDs.generatePlan(
              goal: _goal,
              level: _level,
              frequency: _frequency,
              startDate: startDate,
              confirmOverwrite: true,
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
      // Plano já está sendo gerado no server. /plan-loading mostra o countdown
      // (vê o plano `generating` e não dispara outra geração).
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
          'Para ajustes pontuais, prefira a "Revisão semanal" do plano.',
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
}
