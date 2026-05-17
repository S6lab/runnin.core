import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_body.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_frequency.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_gender.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_goal.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_identity.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_intro.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_level.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_medical.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_pace.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_routine.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_wearable.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _ds = UserRemoteDatasource();
  final _nameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController(text: '70');
  final _heightCtrl = TextEditingController(text: '175');
  final _medicalOtherCtrl = TextEditingController();
  final Set<String> _medicalConditions = {};

  // 3 intro slides + 10 assessment steps. Login mora em /login (antes do onboarding).
  static const _totalSteps = 13;
  static const _firstAssessmentStep = 3;

  int _step = 0;
  String _level = 'iniciante';
  String _goal = 'Completar 10K';
  int _frequency = 4;
  String? _pace;
  String? _runPeriod;
  String? _wakeTime;
  String? _sleepTime;
  String? _gender; // 'male' | 'female' | 'other' | 'na'
  bool _hasWearable = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_handleFieldChange);
    _birthDateCtrl.addListener(_handleFieldChange);
    _weightCtrl.addListener(_handleFieldChange);
    _heightCtrl.addListener(_handleFieldChange);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_handleFieldChange);
    _birthDateCtrl.removeListener(_handleFieldChange);
    _weightCtrl.removeListener(_handleFieldChange);
    _heightCtrl.removeListener(_handleFieldChange);
    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _medicalOtherCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canProceed() || _submitting) return;
    if (FirebaseAuth.instance.currentUser == null) {
      // Router guard já garante que estamos logados ao chegar aqui; defensivo.
      context.go('/login');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });
    _doSubmit();
    if (!mounted) return;
    // Gate freemium: não-premium vai pro paywall. Premium → plan-loading.
    final profile = await _ds.getMe().catchError((_) => null);
    final premium = profile?.premium ?? false;
    if (!mounted) return;
    if (!premium) {
      context.go('/paywall?next=/home');
    } else {
      context.push('/plan-loading');
    }
  }

  Future<void> _doSubmit() async {
    try {
      await _ds.completeOnboarding(
        name: _nameCtrl.text.trim(),
        level: _level,
        goal: _goal,
        frequency: _frequency,
        birthDate: _birthDateCtrl.text.trim().isEmpty
            ? null
            : _birthDateCtrl.text.trim(),
        weight: _weightCtrl.text.trim().isEmpty
            ? null
            : _weightCtrl.text.trim(),
        height: _heightCtrl.text.trim().isEmpty
            ? null
            : _heightCtrl.text.trim(),
        targetPace: _pace,
        hasWearable: _hasWearable,
        medicalConditions: _medicalConditions.toList()..sort(),
        gender: _gender,
        runPeriod: _runPeriod,
        wakeTime: _wakeTime,
        sleepTime: _sleepTime,
      );
      markOnboardingDone();
    } catch (_) {
      // User already navigated to PlanLoadingPage; silent best-effort.
    }
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
                        child: _buildStep(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildNav(context),
                    const SizedBox(height: 12),
                    FigmaOnboardingPageIndicator(total: _totalSteps, currentIndex: _step),
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
    final showSkip = _step < _firstAssessmentStep;

    return Row(
      children: [
        if (canGoBack)
          OutlinedButton(
            onPressed: _submitting ? null : () => setState(() => _step--),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(86, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('< VOLTAR'),
          )
        else
          const SizedBox(width: 86, height: 38),
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
        if (showSkip) ...[
          const SizedBox(width: 18),
          TextButton(
            onPressed: _submitting ? null : _skipIntro,
            child: const Text('PULAR'),
          ),
        ] else
          const SizedBox(width: 66),
      ],
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
      case 1:
      case 2:
        return OnboardingStepIntro(slide: kOnboardingIntroSlides[_step]);
      case 3:
        return OnboardingStepLevel(
          selected: _level,
          onSelect: (value) => setState(() => _level = value),
        );
      case 4:
        return OnboardingStepIdentity(
          nameController: _nameCtrl,
          birthDateController: _birthDateCtrl,
        );
      case 5:
        return OnboardingStepGender(
          selected: _gender,
          onSelect: (value) => setState(() => _gender = value),
        );
      case 6:
        return OnboardingStepBody(
          weightController: _weightCtrl,
          heightController: _heightCtrl,
        );
      case 7:
        return OnboardingStepMedical(
          selected: _medicalConditions,
          otherController: _medicalOtherCtrl,
          onToggle: _toggleMedicalCondition,
          onAddOther: _addOtherMedicalCondition,
        );
      case 8:
        return OnboardingStepGoal(
          selectedGoal: _goal,
          onGoalSelect: (value) => setState(() => _goal = value),
        );
      case 9:
        return OnboardingStepFrequency(
          frequency: _frequency,
          onFreqChange: (value) => setState(() => _frequency = value),
        );
      case 10:
        return OnboardingStepPace(
          selected: _pace,
          onSelect: (value) => setState(() => _pace = value),
        );
      case 11:
        return OnboardingStepRoutine(
          selectedPeriod: _runPeriod,
          selectedWakeTime: _wakeTime,
          selectedSleepTime: _sleepTime,
          onPeriodSelect: (v) => setState(() => _runPeriod = v),
          onWakeTimeSelect: (v) => setState(() => _wakeTime = v),
          onSleepTimeSelect: (v) => setState(() => _sleepTime = v),
        );
      case 12:
        return OnboardingStepWearable(
          selected: _hasWearable,
          onSelect: (value) => setState(() => _hasWearable = value),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNav(BuildContext context) {
    final palette = context.runninPalette;
    final isLastDataStep = _step == _totalSteps - 1;
    final label = isLastDataStep ? 'CRIAR MEU PLANO' : 'CONTINUAR';

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _canProceed()
                ? (isLastDataStep ? _submit : _nextStep)
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
        if (_step == 7)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pode pular se preferir. Voce pode adicionar depois no Perfil.',
              style: context.runninType.bodySm.copyWith(color: palette.muted),
              textAlign: TextAlign.center,
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
      case 4:
        return _nameCtrl.text.trim().isNotEmpty &&
            _isValidBirthDate(_birthDateCtrl.text.trim());
      case 5:
        return _gender != null;
      case 6:
        return _weightCtrl.text.trim().isNotEmpty &&
            _heightCtrl.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  bool _isValidBirthDate(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match == null) return false;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return false;

    try {
      final date = DateTime(year, month, day);
      final isExactDate =
          date.year == year && date.month == month && date.day == day;
      if (!isExactDate) return false;

      final now = DateTime.now();
      final minimumDate = DateTime(now.year - 100, now.month, now.day);
      final maximumDate = DateTime(now.year - 8, now.month, now.day);
      return !date.isBefore(minimumDate) && !date.isAfter(maximumDate);
    } catch (_) {
      return false;
    }
  }

  void _toggleMedicalCondition(String value) {
    setState(() {
      if (_medicalConditions.contains(value)) {
        _medicalConditions.remove(value);
      } else {
        _medicalConditions.add(value);
      }
    });
  }

  void _addOtherMedicalCondition() {
    final value = _medicalOtherCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _medicalConditions.add(value);
      _medicalOtherCtrl.clear();
    });
  }

  void _handleFieldChange() {
    if (!mounted) return;
    setState(() {
      _error = null;
    });
  }

  void _skipIntro() {
    setState(() => _step = _firstAssessmentStep);
  }

  void _handleSwipe(DragEndDetails details) {
    if (_submitting) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300 && _step > 0) {
      setState(() => _step--);
    } else if (velocity < -300 && _step < _totalSteps - 1 && _canProceed()) {
      _nextStep();
    }
  }

  void _nextStep() => setState(() => _step++);
}
