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

  // 3 intro + 1 prep + 10 assessment + 1 start-date = 15 steps.
  static const _totalSteps = 15;
  static const _prepStep = 3;
  static const _firstAssessmentStep = 4;
  static const _startDateStep = 14;

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
  // D0 escolhida no último step do onboarding. Default = hoje.
  late DateTime _startDate = _todayMidnight();
  String _startDateChoice = 'today'; // 'today' | 'tomorrow' | 'next_monday' | 'custom'

  static DateTime _todayMidnight() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _startDateIso() {
    final d = _startDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

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
    final startIso = _startDateIso();
    if (!premium) {
      // Freemium não gera plano AI, mas mantemos startDate como query
      // pra paywall passar adiante se ele assinar.
      context.go('/paywall?next=/home&startDate=$startIso');
    } else {
      context.push('/plan-loading?startDate=$startIso');
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
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildStep(context),
                        ),
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
      case _prepStep:
        return const _OnboardingPrepStep();
      case 4:
        return OnboardingStepLevel(
          selected: _level,
          onSelect: (value) => setState(() => _level = value),
        );
      case 5:
        return OnboardingStepIdentity(
          nameController: _nameCtrl,
          birthDateController: _birthDateCtrl,
        );
      case 6:
        return OnboardingStepGender(
          selected: _gender,
          onSelect: (value) => setState(() => _gender = value),
        );
      case 7:
        return OnboardingStepBody(
          weightController: _weightCtrl,
          heightController: _heightCtrl,
        );
      case 8:
        return OnboardingStepMedical(
          selected: _medicalConditions,
          otherController: _medicalOtherCtrl,
          onToggle: _toggleMedicalCondition,
          onAddOther: _addOtherMedicalCondition,
        );
      case 9:
        return OnboardingStepGoal(
          selectedGoal: _goal,
          onGoalSelect: (value) => setState(() => _goal = value),
        );
      case 10:
        return OnboardingStepFrequency(
          frequency: _frequency,
          onFreqChange: (value) => setState(() => _frequency = value),
        );
      case 11:
        return OnboardingStepPace(
          selected: _pace,
          onSelect: (value) => setState(() => _pace = value),
        );
      case 12:
        return OnboardingStepRoutine(
          selectedPeriod: _runPeriod,
          selectedWakeTime: _wakeTime,
          selectedSleepTime: _sleepTime,
          onPeriodSelect: (v) => setState(() => _runPeriod = v),
          onWakeTimeSelect: (v) => setState(() => _wakeTime = v),
          onSleepTimeSelect: (v) => setState(() => _sleepTime = v),
        );
      case 13:
        return OnboardingStepWearable(
          selected: _hasWearable,
          onSelect: (value) => setState(() => _hasWearable = value),
        );
      case _startDateStep:
        return _OnboardingStartDateStep(
          selected: _startDateChoice,
          customDate: _startDate,
          onSelect: (choice, date) => setState(() {
            _startDateChoice = choice;
            _startDate = date;
          }),
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
        if (_step == 8)
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
      case 5: // identity
        return _nameCtrl.text.trim().isNotEmpty &&
            _isValidBirthDate(_birthDateCtrl.text.trim());
      case 6: // gender
        return _gender != null;
      case 7: // body
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

// ───────────────────────── novos steps ──────────────────────────────

/// Tela de preparação ANTES do assessment. Avisa que o que vem agora
/// é o que vai personalizar o plano — pede atenção e honestidade.
class _OnboardingPrepStep extends StatelessWidget {
  const _OnboardingPrepStep();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// ASSESSMENT'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Vamos montar SEU plano.'),
        const SizedBox(height: 18),
        Text(
          'Pra ter o melhor resultado, preciso da sua atenção total e honestidade nas próximas perguntas.',
          style: context.runninType.bodyMd.copyWith(color: palette.text, height: 1.55),
        ),
        const SizedBox(height: 14),
        Text(
          'Essas informações são a BASE do seu plano individualizado — peso, altura, idade, condições médicas, frequência, objetivo e horários moldam cada sessão.',
          style: context.runninType.bodyMd.copyWith(color: palette.muted, height: 1.55),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.08),
            border: Border.all(color: palette.primary.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: palette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sem dados precisos, o coach gera um plano genérico. Com eles, monta um treino feito pra você.',
                  style: context.runninType.bodySm.copyWith(
                    color: palette.text,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Bora? Toque CONTINUAR pra começar.',
          style: context.runninType.bodyMd.copyWith(
            color: palette.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Último step do onboarding: D0 do plano. User escolhe entre HOJE,
/// AMANHÃ, PRÓXIMA SEGUNDA ou data CUSTOM. Toda periodização (semana 1
/// dia 1, mesociclo end) é calculada a partir daqui.
class _OnboardingStartDateStep extends StatelessWidget {
  final String selected;
  final DateTime customDate;
  final void Function(String choice, DateTime date) onSelect;

  const _OnboardingStartDateStep({
    required this.selected,
    required this.customDate,
    required this.onSelect,
  });

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _tomorrow() => _today().add(const Duration(days: 1));

  static DateTime _nextMonday() {
    final t = _today();
    final dow = t.weekday; // Mon=1...Sun=7
    final daysAhead = dow == 1 ? 7 : (8 - dow);
    return t.add(Duration(days: daysAhead));
  }

  String _fmt(DateTime d) {
    const names = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
    return '${names[d.weekday]} · ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final today = _today();
    final tomorrow = _tomorrow();
    final nextMonday = _nextMonday();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentHeading(text: 'Quando você quer começar?'),
        const SizedBox(height: 10),
        FigmaAssessmentDescription(
          text:
              'A semana 1 e a periodização toda começam nessa data. O coach respeita o D0 que você escolher.',
        ),
        const SizedBox(height: 24),
        _DateChoice(
          label: 'COMEÇAR HOJE',
          subtitle: _fmt(today),
          selected: selected == 'today',
          onTap: () => onSelect('today', today),
        ),
        const SizedBox(height: 8),
        _DateChoice(
          label: 'AMANHÃ',
          subtitle: _fmt(tomorrow),
          selected: selected == 'tomorrow',
          onTap: () => onSelect('tomorrow', tomorrow),
        ),
        const SizedBox(height: 8),
        _DateChoice(
          label: 'PRÓXIMA SEGUNDA',
          subtitle: _fmt(nextMonday),
          selected: selected == 'next_monday',
          onTap: () => onSelect('next_monday', nextMonday),
        ),
        const SizedBox(height: 8),
        _DateChoice(
          label: 'ESCOLHER DATA',
          subtitle: selected == 'custom'
              ? _fmt(customDate)
              : 'toque pra abrir o calendário',
          selected: selected == 'custom',
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: customDate,
              firstDate: today,
              lastDate: today.add(const Duration(days: 60)),
            );
            if (picked != null) onSelect('custom', picked);
          },
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Dica: começar amanhã ou próxima segunda dá tempo de ajustar a rotina e separar o material (tênis, garrafa, etc).',
            style: context.runninType.bodySm.copyWith(
              color: palette.muted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateChoice extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DateChoice({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.12)
              : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.runninType.labelMd.copyWith(
                color: selected ? palette.primary : palette.text,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: context.runninType.bodySm.copyWith(
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
