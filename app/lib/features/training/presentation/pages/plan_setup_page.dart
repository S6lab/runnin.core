import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/history/data/stats_remote_datasource.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_start_date.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/subscriptions/presentation/widgets/premium_locked_card.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/plan_admissibility.dart';
import 'package:runnin/features/training/presentation/steps/step_current_capacity.dart';
import 'package:runnin/features/training/presentation/steps/step_days.dart';
import 'package:runnin/features/training/presentation/steps/step_goal_v3.dart';
import 'package:runnin/features/training/presentation/steps/step_level_v2.dart';
import 'package:runnin/features/training/presentation/steps/step_race_extras.dart';
import 'package:runnin/features/training/presentation/steps/step_routine.dart';
import 'package:runnin/features/training/presentation/widgets/admissibility_sheet.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Jornada V3 de criação do plano com branching FLOW/RACE:
///  - sempre: intro → nível → goalKind → capacidade atual → dias+freq+longRun → startDate
///  - FLOW adiciona: flowSubgoal entre goalKind e capacidade
///  - RACE adiciona: raceDistance/mode → (targetPace se improve_pace) → window → raceDate
///
/// Total: 7 telas FLOW, 9-10 telas RACE. Wizard usa lista dinâmica calculada
/// a cada build (`_resolveSteps()`) baseada em goalKind + raceMode.
class PlanSetupPage extends StatefulWidget {
  const PlanSetupPage({super.key});

  @override
  State<PlanSetupPage> createState() => _PlanSetupPageState();
}

/// Identificadores das telas. Ordem aqui não importa — sequência é montada em
/// `_resolveSteps()`. Cada enum tem builder próprio em `_buildStep()`.
enum _Step {
  intro,
  level,
  goalKind,
  flowSubgoal,
  raceDistance,
  currentCapacity,
  raceTargetPace,
  raceWindow,
  raceDate,
  daysAndFreq,
  routine,
  startDate,
}

class _PlanSetupPageState extends State<PlanSetupPage> {
  final _userDs = UserRemoteDatasource();
  final _planDs = PlanRemoteDatasource();
  final _statsDs = StatsRemoteDatasource();

  int _stepIdx = 0;

  // Estado da jornada
  PlanLevelChoice? _level;
  PlanLevelChoice? _suggestedLevel;
  PlanGoalKind? _goalKind;
  PlanFlowSubgoal? _flowSubgoal;
  int? _raceDistanceKm;
  PlanRaceMode? _raceMode;
  String? _targetPaceMinKm; // M:SS/km
  String? _windowMode; // 'aggressive' | 'feasible' | 'safe'
  DateTime? _raceDate;
  Set<int> _availableDays = {1, 3, 5, 6};
  int _frequency = 4;
  int? _longRunDayOfWeek;
  int? _longRunMaxMinutes;
  bool? _alreadyRuns;
  int? _capacityDistanceKm;
  int? _capacityTimeSec;
  double? _weeklyKm;
  String? _historyHint;
  String? _profileBirthDate;
  List<String> _profileMedicalConditions = const [];
  String? _runPeriod;
  String? _wakeTime;
  String? _sleepTime;
  String _startChoice = 'today';
  DateTime _customDate = OnboardingStartDateStep.today();

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistoryAndSuggest();
    _loadProfileForAdmissibility();
  }

  Future<void> _loadProfileForAdmissibility() async {
    try {
      final profile = await _userDs.getMe();
      if (profile == null || !mounted) return;
      setState(() {
        _profileBirthDate = profile.birthDate;
        _profileMedicalConditions = profile.medicalConditions;
        // Pre-fill da tela de rotina com os dados do onboarding quando
        // existem. User pode trocar livre.
        _runPeriod ??= profile.runPeriod;
        _wakeTime ??= profile.wakeTime;
        _sleepTime ??= profile.sleepTime;
      });
    } catch (_) {/* sem profile = sem checks de age/medical */}
  }

  /// Pace atual derivado da tela de capacidade (M:SS/km) ou null se user
  /// disse que não corre / não preencheu.
  String? get _currentPaceMinKm {
    if (_alreadyRuns != true || _capacityDistanceKm == null || _capacityTimeSec == null || _capacityTimeSec! <= 0) {
      return null;
    }
    final paceSec = _capacityTimeSec! / _capacityDistanceKm!;
    final m = paceSec ~/ 60;
    final s = (paceSec % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Semanas alvo derivadas da janela escolhida (RACE) ou padrão (FLOW).
  int? get _weeksCount {
    if (_goalKind == PlanGoalKind.race && _raceDate != null) {
      final start = _startDateValue();
      return ((_raceDate!.difference(start).inDays + 1) / 7).round();
    }
    return null;
  }

  DateTime _startDateValue() {
    return _startChoice == 'today' ? DateTime.now() : _customDate;
  }

  /// `goal` legado pro backend (string livre). Server prefere goalKind +
  /// raceDistanceKm pra interpretar, mas o campo `goal` continua required.
  String get _backendGoal {
    if (_goalKind == PlanGoalKind.race && _raceDistanceKm != null) {
      switch (_raceDistanceKm) {
        case 5:
          return 'Completar 5K';
        case 10:
          return 'Completar 10K';
        case 21:
          return 'Meia maratona (21K)';
        case 42:
          return 'Maratona (42K)';
      }
    }
    return 'flow';
  }

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
          _historyHint = 'Últimas 4 semanas: ${weeklyKm.toStringAsFixed(1)} km/sem · pace ${stats.avgPace ?? '—'}';
          _weeklyKm ??= weeklyKm;
        }
      });
    } catch (_) {/* offline OK */}
  }

  static int? _paceLabelToSec(String? label) {
    if (label == null || label.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(label);
    if (m == null) return null;
    return (int.tryParse(m.group(1)!) ?? 0) * 60 + (int.tryParse(m.group(2)!) ?? 0);
  }

  /// Calcula a sequência de telas baseada em goalKind + raceMode atuais.
  /// Recalcula a cada build pra reagir a mudanças mid-wizard (ex: user
  /// volta e troca de FLOW pra RACE).
  ///
  /// Ordem: intro → goalKind (intenção primeiro) → level → daysAndFreq →
  /// sub-meta (flowSubgoal ou raceDistance) → currentCapacity → (race extras)
  /// → startDate. Goal vem antes pra usuário declarar intenção; level+freq
  /// vêm antes da escolha de distância pra cards filtrarem por MIN_FREQ +
  /// levelHint.
  List<_Step> _resolveSteps() {
    final steps = <_Step>[
      _Step.intro,
      _Step.goalKind,
      _Step.level,
      _Step.daysAndFreq,
    ];
    if (_goalKind == PlanGoalKind.flow) {
      steps.add(_Step.flowSubgoal);
    } else if (_goalKind == PlanGoalKind.race) {
      steps.add(_Step.raceDistance);
    }
    // Pula capacity quando user marcou "nunca corri" — não há capacidade
    // pra reportar. Server recebe currentWeeklyKm=null/0 e currentPaceMinKm=null,
    // o que joga o user direto no ramp-from-zero (walk-run 5km/sem baseline).
    if (_level?.levelHint != 'nunca_corri') {
      steps.add(_Step.currentCapacity);
    }
    if (_goalKind == PlanGoalKind.race) {
      if (_raceMode == PlanRaceMode.improvePace) {
        steps.add(_Step.raceTargetPace);
      }
      steps.add(_Step.raceWindow);
      steps.add(_Step.raceDate);
    }
    // Rotina (período + acorda + dorme) — coach distribui sessões duras
    // nos horários de pico de energia. Vem antes do startDate.
    steps.add(_Step.routine);
    steps.add(_Step.startDate);
    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: ListenableBuilder(
        listenable: subscriptionController,
        builder: (context, _) {
          if (!subscriptionController.has('generatePlan')) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('VOLTAR'),
                    ),
                    const SizedBox(height: 24),
                    PremiumLockedCard(
                      title: 'GERAR PLANO COM IA',
                      description:
                          'A geração de plano com coach AI personalizado '
                          'é exclusiva do Premium. Após assinar, você volta '
                          'pra esta tela pra continuar a configuração.',
                      icon: Icons.auto_awesome_outlined,
                      next: '/training/criar-plano',
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildSetupBody(context);
        },
      ),
    );
  }

  Widget _buildSetupBody(BuildContext context) {
    final steps = _resolveSteps();
    final total = steps.length;
    final clampedIdx = _stepIdx.clamp(0, total - 1);
    return Column(
      children: [
        FigmaOnboardingTopProgressBar(total: total, currentIndex: clampedIdx),
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
                      onHorizontalDragEnd: (d) => _handleSwipe(d, steps),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildStep(context, steps[clampedIdx]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildNav(context, steps),
                  const SizedBox(height: 12),
                  FigmaOnboardingPageIndicator(
                    total: total,
                    currentIndex: clampedIdx,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = context.runninPalette;
    final canGoBack = _stepIdx > 0;
    return Row(
      children: [
        OutlinedButton(
          onPressed: _submitting
              ? null
              : () {
                  if (canGoBack) {
                    setState(() => _stepIdx--);
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

  Widget _buildStep(BuildContext context, _Step step) {
    switch (step) {
      case _Step.intro:
        return const OnboardingPrepStep();
      case _Step.level:
        return PlanStepLevelV2(
          selected: _level,
          suggested: _suggestedLevel,
          onSelect: (v) => setState(() {
            _level = v;
            // Se mudou pra "nunca corri", limpa o state de capacidade pra
            // não persistir dado de outra escolha + força walk-run baseline.
            if (v.levelHint == 'nunca_corri') {
              _alreadyRuns = false;
              _capacityDistanceKm = null;
              _capacityTimeSec = null;
              _weeklyKm = null;
            }
          }),
        );
      case _Step.goalKind:
        return StepGoalKind(
          selected: _goalKind,
          onSelect: (v) => setState(() {
            _goalKind = v;
            // Reset state contextual quando troca o tipo de meta
            if (v == PlanGoalKind.flow) {
              _raceDistanceKm = null;
              _raceMode = null;
              _targetPaceMinKm = null;
              _windowMode = null;
              _raceDate = null;
            } else {
              _flowSubgoal = null;
              // Race mínimo absoluto = 2 treinos/sem (1 não periodiza).
              // Se vinha de flow com freq=1, sobe pra 2 — assim os chips
              // renderizados (que começam em 2) batem com o estado.
              if (_frequency < 2) _frequency = 2;
            }
          }),
        );
      case _Step.flowSubgoal:
        return StepFlowSubgoal(
          selected: _flowSubgoal,
          onSelect: (v) => setState(() => _flowSubgoal = v),
        );
      case _Step.raceDistance:
        return StepRaceDistance(
          selectedDistance: _raceDistanceKm,
          selectedMode: _raceMode,
          level: _level?.backendLevel,
          levelHint: _level?.levelHint,
          frequency: _frequency,
          onSelectDistance: (d) => setState(() {
            _raceDistanceKm = d;
            // Pra "nunca correu" não tem improve_pace (sem pace pra
            // melhorar) — auto-seta complete pra não trancar o wizard.
            if (_level?.levelHint == 'nunca_corri') {
              _raceMode = PlanRaceMode.complete;
              _targetPaceMinKm = null;
            }
          }),
          onSelectMode: (m) => setState(() {
            _raceMode = m;
            if (m != PlanRaceMode.improvePace) _targetPaceMinKm = null;
          }),
        );
      case _Step.daysAndFreq:
        return PlanStepDays(
          availableDays: _availableDays,
          frequency: _frequency,
          longRunDayOfWeek: _longRunDayOfWeek,
          longRunMaxMinutes: _longRunMaxMinutes,
          raceDistanceKm: _goalKind == PlanGoalKind.race ? _raceDistanceKm : null,
          isRaceGoal: _goalKind == PlanGoalKind.race,
          level: _level?.backendLevel,
          levelHint: _level?.levelHint,
          raceMode: _goalKind == PlanGoalKind.race ? _raceMode?.backendValue : null,
          onDaysChange: (days) => setState(() {
            _availableDays = days;
            if (_longRunDayOfWeek != null && !days.contains(_longRunDayOfWeek)) {
              _longRunDayOfWeek = null;
              _longRunMaxMinutes = null;
            }
          }),
          onFreqChange: (f) => setState(() {
            _frequency = f;
            // Inverteu a ordem: freq primeiro, dias depois. Quando user
            // sobe a freq pra mais do que tem marcado, auto-completa com
            // dias padrão (seg/qua/sex/etc) pra cobrir o mínimo. Sem isso
            // o gate de "marcar X dias" trava o user.
            if (f > _availableDays.length) {
              final fallback = [1, 3, 5, 2, 4, 6, 7];
              final next = {..._availableDays};
              for (final d in fallback) {
                if (next.length >= f) break;
                next.add(d);
              }
              _availableDays = next;
            }
          }),
          onLongRunDayChange: (d) => setState(() {
            _longRunDayOfWeek = d;
            if (d == null) _longRunMaxMinutes = null;
          }),
          onLongRunMaxMinutesChange: (m) => setState(() => _longRunMaxMinutes = m),
        );
      case _Step.currentCapacity:
        return StepCurrentCapacity(
          selectedDistanceKm: _capacityDistanceKm,
          timeSeconds: _capacityTimeSec,
          weeklyKm: _weeklyKm,
          alreadyRuns: _alreadyRuns,
          historyHint: _historyHint,
          raceDistanceKm: _goalKind == PlanGoalKind.race ? _raceDistanceKm : null,
          weeksCount: _weeksCount,
          onAlreadyRunsChange: (v) => setState(() {
            _alreadyRuns = v;
            if (!v) {
              _capacityDistanceKm = null;
              _capacityTimeSec = null;
              _weeklyKm = null;
            }
          }),
          onDistanceChange: (d) => setState(() => _capacityDistanceKm = d),
          onTimeChange: (s) => setState(() => _capacityTimeSec = s),
          onWeeklyKmChange: (v) => setState(() => _weeklyKm = v),
        );
      case _Step.raceTargetPace:
        return StepRaceTargetPace(
          currentPaceMinKm: _currentPaceMinKm,
          targetPace: _targetPaceMinKm,
          level: _level?.backendLevel ?? 'iniciante',
          weeksCount: _weeksCount ?? RaceWindowsTable.lookup(
                  _raceDistanceKm ?? 10,
                  _level?.backendLevel ?? 'iniciante')?.feasible ??
              12,
          onSelect: (p) => setState(() => _targetPaceMinKm = p),
        );
      case _Step.raceWindow:
        return StepRaceWindow(
          raceDistanceKm: _raceDistanceKm ?? 10,
          level: _level?.backendLevel ?? 'iniciante',
          levelHint: _level?.levelHint,
          raceMode: _raceMode?.backendValue,
          startDate: _startDateValue(),
          selectedMode: _windowMode,
          userAge: _computeAgeFromBirthDate(),
          medicalConditions: _profileMedicalConditions,
          frequency: _frequency,
          currentWeeklyKm: _weeklyKm,
          onSelect: (mode) => setState(() {
            _windowMode = mode;
            // Auto-set raceDate baseado na janela escolhida
            final row = RaceWindowsTable.lookup(
                _raceDistanceKm ?? 10, _level?.backendLevel ?? 'iniciante');
            if (row != null) {
              final weeks = mode == 'aggressive'
                  ? row.aggressive ?? row.feasible ?? row.safe
                  : mode == 'feasible'
                      ? row.feasible ?? row.safe
                      : row.safe;
              _raceDate = _startDateValue().add(Duration(days: weeks * 7 - 1));
            }
          }),
        );
      case _Step.raceDate:
        final row = RaceWindowsTable.lookup(
            _raceDistanceKm ?? 10, _level?.backendLevel ?? 'iniciante');
        final defaultWeeks = row?.feasible ?? row?.safe ?? 12;
        return StepRaceDate(
          startDate: _startDateValue(),
          defaultWeeks: defaultWeeks,
          selectedDate: _raceDate,
          onSelect: (d) => setState(() => _raceDate = d),
        );
      case _Step.routine:
        return StepRoutine(
          runPeriod: _runPeriod,
          wakeTime: _wakeTime,
          sleepTime: _sleepTime,
          onPeriodSelect: (p) => setState(() => _runPeriod = p),
          onWakeTimeSelect: (t) => setState(() => _wakeTime = t),
          onSleepTimeSelect: (t) => setState(() => _sleepTime = t),
        );
      case _Step.startDate:
        return OnboardingStartDateStep(
          selected: _startChoice,
          customDate: _customDate,
          onSelect: (choice, date) => setState(() {
            _startChoice = choice;
            _customDate = date;
          }),
        );
    }
  }

  Widget _buildNav(BuildContext context, List<_Step> steps) {
    final palette = context.runninPalette;
    final isLast = _stepIdx == steps.length - 1;
    final label = isLast ? 'CRIAR PLANO' : 'CONTINUAR';
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _canProceed(steps[_stepIdx])
                ? (isLast ? _submit : () => setState(() => _stepIdx++))
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

  bool _canProceed(_Step step) {
    if (_submitting) return false;
    switch (step) {
      case _Step.intro:
        return true;
      case _Step.level:
        return _level != null;
      case _Step.goalKind:
        return _goalKind != null;
      case _Step.flowSubgoal:
        return _flowSubgoal != null;
      case _Step.raceDistance:
        return _raceDistanceKm != null && _raceMode != null;
      case _Step.daysAndFreq:
        if (_availableDays.isEmpty) return false;
        return _frequency >= 1 && _frequency <= _availableDays.length;
      case _Step.currentCapacity:
        if (_alreadyRuns == null) return false;
        if (_alreadyRuns == false) return true;
        return _capacityDistanceKm != null &&
            _capacityTimeSec != null &&
            _capacityTimeSec! > 0;
      case _Step.raceTargetPace:
        return _targetPaceMinKm != null;
      case _Step.raceWindow:
        return _windowMode != null;
      case _Step.raceDate:
        return _raceDate != null;
      case _Step.routine:
        return _runPeriod != null && _wakeTime != null && _sleepTime != null;
      case _Step.startDate:
        return true;
    }
  }

  void _handleSwipe(DragEndDetails details, List<_Step> steps) {
    if (_submitting) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300 && _stepIdx > 0) {
      setState(() => _stepIdx--);
    } else if (velocity < -300 && _stepIdx < steps.length - 1 && _canProceed(steps[_stepIdx])) {
      setState(() => _stepIdx++);
    }
  }

  String _startDateIso() {
    final d = _customDate;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  int? _computeAgeFromBirthDate() {
    final b = _profileBirthDate;
    if (b == null || b.isEmpty) return null;
    DateTime? d;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(b)) {
      d = DateTime.tryParse(b);
    } else if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(b)) {
      final p = b.split('/');
      d = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
    }
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age;
  }

  AdmissibilityState _buildAdmissibilityState() {
    return AdmissibilityState(
      goalKind: _goalKind?.backendValue,
      flowSubgoal: _flowSubgoal?.backendValue,
      raceDistanceKm: _raceDistanceKm,
      raceMode: _raceMode?.backendValue,
      targetPaceMinKm: _targetPaceMinKm,
      currentPaceMinKm: _currentPaceMinKm,
      level: _level?.backendLevel,
      levelHint: _level?.levelHint,
      frequency: _frequency,
      availableDaysCount: _availableDays.length,
      currentWeeklyKm: _weeklyKm,
      weeksCount: _weeksCount,
      windowMode: _windowMode,
      birthDate: _profileBirthDate,
      medicalConditions: _profileMedicalConditions,
    );
  }

  /// Aplica uma sugestão do BottomSheet — muta state + navega pra step
  /// relevante. Não re-submete automaticamente (deixa user revisar).
  void _applySuggestion(AdmissibilitySuggestion s) {
    final steps = _resolveSteps();
    setState(() {
      _error = null;
      if (s is IncreaseFrequency) {
        _frequency = s.toN;
        // Garante availableDays suficientes
        if (_availableDays.length < s.toN) {
          final all = {1, 2, 3, 4, 5, 6, 7};
          final missing = (all.difference(_availableDays)).take(s.toN - _availableDays.length);
          _availableDays = {..._availableDays, ...missing};
        }
        _stepIdx = steps.indexOf(_Step.daysAndFreq);
      } else if (s is SwitchDistance) {
        _raceDistanceKm = s.toKm;
        _windowMode = null;
        _raceDate = null;
        _targetPaceMinKm = null;
        _stepIdx = steps.indexOf(_Step.raceDistance);
      } else if (s is SwitchToSafeWindow) {
        _windowMode = 'safe';
        _raceDate = _startDateValue().add(Duration(days: s.weeks * 7 - 1));
        final idx = _resolveSteps().indexOf(_Step.raceWindow);
        if (idx >= 0) _stepIdx = idx;
      } else if (s is RelaxPaceTarget) {
        _targetPaceMinKm = s.toPace;
        final idx = _resolveSteps().indexOf(_Step.raceTargetPace);
        if (idx >= 0) _stepIdx = idx;
      } else if (s is SwitchToCompleteMode) {
        _raceMode = PlanRaceMode.complete;
        _targetPaceMinKm = null;
        _stepIdx = steps.indexOf(_Step.raceDistance);
      } else if (s is SwitchToFlow) {
        _goalKind = PlanGoalKind.flow;
        _raceDistanceKm = null;
        _raceMode = null;
        _targetPaceMinKm = null;
        _windowMode = null;
        _raceDate = null;
        _stepIdx = _resolveSteps().indexOf(_Step.goalKind);
      }
      // Clamp pra evitar index inválido após mudança da árvore
      final newSteps = _resolveSteps();
      if (_stepIdx < 0 || _stepIdx >= newSteps.length) {
        _stepIdx = 0;
      }
    });
  }

  String _raceDateIso() {
    final d = _raceDate!;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_submitting) return;

    // Pre-submit admissibility guard: roda as mesmas regras do server
    // client-side. Se algo bate, abre BottomSheet com sugestões em vez
    // de chamar /plans/generate e mostrar 422 técnico no fim.
    final adm = checkAdmissibility(_buildAdmissibilityState());
    if (!adm.ok) {
      await AdmissibilitySheet.show(
        context,
        result: adm,
        onPick: _applySuggestion,
      );
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    await subscriptionController.refresh();
    if (!subscriptionController.has('generatePlan')) {
      if (!mounted) return;
      setState(() => _submitting = false);
      context.push('/paywall?next=/training/criar-plano');
      return;
    }

    final level = _level!;
    final availableDays = (_availableDays.toList()..sort());
    final startDate = _startChoice == 'today' ? null : _startDateIso();

    try {
      // Limpa cache do plan ANTES do generate. Sem isso, a tela seguinte
      // (plan_loading) pode ler o plano antigo via cache local e mostrar
      // como se fosse o novo. clearPlanCache também roda DEPOIS do generate
      // no datasource, mas o "antes" cobre a janela enquanto o LLM gera.
      PlanRemoteDatasource.clearPlanCache();
      await _userDs.patchMe(
        level: level.backendLevel,
        goal: _backendGoal,
        frequency: _frequency,
        availableDays: availableDays,
        runPeriod: _runPeriod,
        wakeTime: _wakeTime,
        sleepTime: _sleepTime,
      );

      await _generateWithRetry(
        startDate: startDate,
        availableDays: availableDays,
        confirmOverwrite: false,
      );

      if (!mounted) return;
      final qp = startDate == null ? '' : '?startDate=$startDate';
      context.go('/plan-loading$qp');
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        // _error já foi setado pelos handlers internos quando aplicável
        _error ??= 'Não consegui gerar seu plano agora. Confira sua conexão e tente de novo.';
      }
    }
  }

  Future<void> _generateWithRetry({
    required String? startDate,
    required List<int> availableDays,
    required bool confirmOverwrite,
  }) async {
    final level = _level!;
    try {
      await _planDs.generatePlan(
        goal: _backendGoal,
        level: level.backendLevel,
        frequency: _frequency,
        startDate: startDate,
        confirmOverwrite: confirmOverwrite,
        levelHint: level.levelHint,
        currentPaceMinKm: _currentPaceMinKm,
        currentWeeklyKm: _weeklyKm,
        availableDays: availableDays.isEmpty ? null : availableDays,
        goalKind: _goalKind?.backendValue,
        flowSubgoal: _flowSubgoal?.backendValue,
        raceDistanceKm: _raceDistanceKm,
        raceMode: _raceMode?.backendValue,
        targetPaceMinKm: _targetPaceMinKm,
        raceDate: _raceDate != null ? _raceDateIso() : null,
        longRunDayOfWeek: _longRunDayOfWeek,
        longRunMaxMinutes: _longRunMaxMinutes,
        weeksCount: _weeksCount,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final errMap = body is Map ? body['error'] : null;
      final code = errMap is Map ? errMap['code'] as String? : null;

      if (status == 403) {
        if (!mounted) return;
        context.push('/paywall?next=/training/criar-plano');
        return;
      }
      if (status == 422 && code == 'GOAL_WINDOW_INVALID') {
        final reason = (errMap as Map)['reason'] as String?;
        if (reason == 'requires_redirect') {
          final redirect = errMap['redirect'] as Map?;
          await _handleRedirect(redirect);
          return;
        }
        // too_aggressive: avisa e volta pra tela de janela
        final minWeeks = errMap['minWeeks'] as int?;
        if (mounted) {
          setState(() => _error = 'Janela curta demais. Mínimo $minWeeks semanas pra essa meta.');
        }
        return;
      }
      if (status == 422 && code == 'PACE_TARGET_INVALID') {
        final suggested = (errMap as Map)['suggestedTargetPaceMinKm'] as String?;
        if (mounted) {
          setState(() {
            _error = 'Pace alvo fora do factível. Sugestão do coach: $suggested/km. Volta e ajusta.';
          });
        }
        return;
      }
      if (status == 422 && code == 'FREQUENCY_INVALID') {
        final reason = (errMap as Map)['reason'] as String?;
        final minFreq = errMap['minFrequencyRequired'] as int?;
        final minDays = errMap['minAvailableDays'] as int?;
        String msg;
        if (reason == 'available_days_too_few') {
          msg = 'Marca pelo menos $minDays dias na tela de dias disponíveis pra essa freq de treino.';
        } else if (reason == 'session_volume_too_high') {
          final cap = errMap['maxKmPerSession'] as int?;
          final projected = errMap['projectedKmPerSession'] as num?;
          msg = 'Com essa freq cada sessão fica ~${projected?.toStringAsFixed(0)}km (acima do cap ${cap}km/sessão pro teu nível). Aumenta pra $minFreq treinos/sem ou diminui a distância alvo.';
        } else {
          msg = 'Pra essa distância, mínimo $minFreq treinos/sem. Volta e aumenta a frequência.';
        }
        if (mounted) setState(() => _error = msg);
        return;
      }
      if (status == 422 && code == 'AGE_RESTRICTION') {
        final age = (errMap as Map)['age'] as int?;
        final recommended = errMap['recommendedMinWindow'] as String?;
        final label = recommended == 'safe' ? 'SEGURA' : 'FACTÍVEL';
        if (mounted) {
          setState(() {
            _error = 'Aos $age anos pra essa distância, recomendamos janela $label no mínimo. Volta e escolhe a opção compatível.';
            // Auto-reset windowMode pra forçar nova escolha
            _windowMode = null;
            _raceDate = null;
          });
        }
        return;
      }
      if (status == 422 && code == 'MEDICAL_RESTRICTION') {
        final conditions = ((errMap as Map)['matchedConditions'] as List?)?.cast<String>() ?? [];
        if (mounted) {
          setState(() {
            _error = 'Pelas suas condições (${conditions.join(', ')}), recomendamos janela SEGURA. Volta e escolhe a opção segura.';
            _windowMode = null;
            _raceDate = null;
          });
        }
        return;
      }
      if (status == 409) {
        final confirmed = await _confirmOverwrite();
        if (confirmed != true) return;
        await _generateWithRetry(
          startDate: startDate,
          availableDays: availableDays,
          confirmOverwrite: true,
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> _handleRedirect(Map? redirect) async {
    if (redirect == null) {
      if (mounted) setState(() => _error = 'Meta inviável pro seu perfil. Volta e ajuste.');
      return;
    }
    final distanceKm = (redirect['distanceKm'] as num?)?.toInt();
    final suggestedWeeks = (redirect['suggestedWeeks'] as num?)?.toInt();
    if (distanceKm == null) return;

    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.runninPalette;
        return AlertDialog(
          backgroundColor: palette.surface,
          title: const Text('Vamos mais leve nessa Fase 1'),
          content: Text(
            'Pra você sair de onde está pra ${_raceDistanceKm}K, o caminho seguro pede '
            'mais base. Sugiro começarmos com ${distanceKm}K em $suggestedWeeks semanas '
            'como Fase 1. Depois rampamos pra meta original.\n\n'
            'Você prefere assim ou volta e ajusta a meta?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('VOLTAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('VAI DE ${distanceKm}K'),
            ),
          ],
        );
      },
    );

    if (accept == true && mounted) {
      // Aceita o redirect: ajusta distância + zera janela/data pra recalibrar
      setState(() {
        _raceDistanceKm = distanceKm;
        _windowMode = null;
        _raceDate = null;
        _error = null;
      });
      // Volta o user pra tela de janela pra reescolher
      final steps = _resolveSteps();
      final windowIdx = steps.indexOf(_Step.raceWindow);
      if (windowIdx >= 0) {
        setState(() => _stepIdx = windowIdx);
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
}
