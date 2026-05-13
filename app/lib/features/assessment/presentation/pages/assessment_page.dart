import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/assessment/data/models/assessment_data.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:dio/dio.dart';

class AssessmentPage extends StatefulWidget {
  final bool redo;

  const AssessmentPage({super.key, this.redo = false});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  final _ds = UserRemoteDatasource();
  final _data = AssessmentData();
  final _nameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController(text: '70');
  final _heightCtrl = TextEditingController(text: '175');
  final _medicalOtherCtrl = TextEditingController();

  static const _totalSteps = 9;
  static const _loadingStep = _totalSteps;

  int _step = 0;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() => _error = null));
    _birthDateCtrl.addListener(() => setState(() => _error = null));
    _weightCtrl.addListener(() => setState(() => _error = null));
    _heightCtrl.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(() {});
    _birthDateCtrl.removeListener(() {});
    _weightCtrl.removeListener(() {});
    _heightCtrl.removeListener(() {});
    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _medicalOtherCtrl.dispose();
    super.dispose();
  }

  static const _levels = [
    ('iniciante', 'Iniciante', 'nunca corri ou voltando'),
    ('intermediario', 'Intermedi\u00e1rio', 'corro regularmente'),
    ('avancado', 'Avan\u00e7ado', 'treino estruturado'),
  ];

  static const _goals = [
    'Sa\u00fade e bem-estar',
    'Perder peso',
    'Completar 5K',
    'Completar 10K',
    'Meia maratona (21K)',
    'Maratona (42K)',
    'Ultramaratona',
    'Triathlon',
  ];

  static const _paceOptions = [
    'N\u00e3o sei o que \u00e9 pace',
    'Acima de 7:00/km',
    'Entre 6:00 e 7:00/km',
    'Entre 5:00 e 6:00/km',
    'Abaixo de 5:00/km',
    'Deixa o Coach decidir',
  ];

  static const _runTimeOptions = [
    ('manha', 'Manh\u00e3', '06-09h', 'Cortisol alto, queima de gordura'),
    ('tarde', 'Tarde', '14-17h', 'Pico de temperatura corporal'),
    ('noite', 'Noite', '19-21h', 'For\u00e7a muscular elevada'),
  ];

  static const _wakeOptions = ['05:00', '06:00', '07:00', '08:00'];
  static const _sleepOptions = ['21:00', '22:00', '23:00', '00:00'];

  static const _wearableOptions = [
    (true, 'Sim (recomendado)',
        'Dados de BPM, sono e atividade permitem que o Coach personalize com mais precis\u00e3o.'),
    (false, 'Depois',
        'Nenhum dado ser\u00e1 tratado como conectado por enquanto.'),
  ];

  static const _medicalOptions = [
    'Hipertens\u00e3o',
    'Diabetes tipo 2',
    'Asma',
    'Hist\u00f3rico de AVC',
    'Problemas card\u00edacos',
    'Les\u00e3o no joelho',
    'Les\u00e3o no tornozelo',
    'H\u00e9rnia de disco',
    'Toma anticoagulante',
    'Toma betabloqueador',
    'Toma insulina',
    'Artrose',
    'Fibromialgia',
    'Ansiedade/depress\u00e3o',
    'Cirurgia recente (<6m)',
  ];

  Future<void> _submit() async {
    if (!_canProceed() || _submitting) return;

    // Check authentication
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _error = 'Entre para salvar seu plano.');
      return;
    }

    // Haptic feedback on submission
    HapticFeedback.mediumImpact();

    setState(() {
      _step = _loadingStep;
      _error = null;
      _submitting = true;
    });

    try {
      await _ds.completeOnboarding(
        name: _data.name,
        level: _data.level,
        goal: _data.goal,
        frequency: _data.frequency,
        birthDate: _data.birthDate.isEmpty ? null : _data.birthDate,
        weight: _data.weight.isEmpty ? null : _data.weight,
        height: _data.height.isEmpty ? null : _data.height,
        hasWearable: _data.hasWearable,
        medicalConditions: _data.medicalConditions.toList()..sort(),
        paceTarget: _data.paceTarget.isEmpty ? null : _data.paceTarget,
        preferredRunTime:
            _data.preferredRunTime.isEmpty ? null : _data.preferredRunTime,
        wakeUpTime: _data.wakeUpTime.isEmpty ? null : _data.wakeUpTime,
        sleepTime: _data.sleepTime.isEmpty ? null : _data.sleepTime,
      );

      // Success haptic feedback
      HapticFeedback.lightImpact();
      markOnboardingDone();

      if (mounted) {
        context.go('/home');
      }
    } on DioException catch (e) {
      if (!mounted) return;

      String errorMessage;

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage =
            'Tempo esgotado. A geração do plano pode demorar alguns segundos. Tente novamente.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Sem conexão com a internet. Verifique sua conexão e tente novamente.';
      } else if (e.response?.statusCode == 401) {
        // Auth token expired - try to refresh and retry once
        try {
          await currentUser.getIdToken(true);
          // Retry submission after token refresh
          await _retrySubmission();
          return;
        } catch (_) {
          errorMessage = 'Sessão expirada. Faça login novamente.';
        }
      } else if (e.response?.statusCode == 400) {
        // Validation error from backend
        final message = e.response?.data?['message'] as String?;
        errorMessage = message ?? 'Dados inválidos. Verifique os campos.';
      } else if (e.response?.statusCode == 429) {
        errorMessage =
            'Você já refez seu plano recentemente. Aguarde alguns dias.';
      } else if (e.response?.statusCode != null &&
          e.response!.statusCode! >= 500) {
        errorMessage =
            'Erro no servidor. Nossa equipe já foi notificada. Tente novamente em alguns minutos.';
      } else {
        errorMessage = 'Erro ao salvar perfil. Tente novamente.';
      }

      // Error haptic feedback
      HapticFeedback.heavyImpact();

      setState(() {
        _error = errorMessage;
        _step = _loadingStep - 1;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;

      // Generic error
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Erro inesperado. Tente novamente.';
        _step = _loadingStep - 1;
        _submitting = false;
      });
    }
  }

  Future<void> _retrySubmission() async {
    try {
      await _ds.completeOnboarding(
        name: _data.name,
        level: _data.level,
        goal: _data.goal,
        frequency: _data.frequency,
        birthDate: _data.birthDate.isEmpty ? null : _data.birthDate,
        weight: _data.weight.isEmpty ? null : _data.weight,
        height: _data.height.isEmpty ? null : _data.height,
        hasWearable: _data.hasWearable,
        medicalConditions: _data.medicalConditions.toList()..sort(),
        paceTarget: _data.paceTarget.isEmpty ? null : _data.paceTarget,
        preferredRunTime:
            _data.preferredRunTime.isEmpty ? null : _data.preferredRunTime,
        wakeUpTime: _data.wakeUpTime.isEmpty ? null : _data.wakeUpTime,
        sleepTime: _data.sleepTime.isEmpty ? null : _data.sleepTime,
      );

      HapticFeedback.lightImpact();
      markOnboardingDone();

      if (mounted) {
        context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'Sessão expirada. Faça login novamente.';
          _step = _loadingStep - 1;
          _submitting = false;
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              Expanded(child: _buildStep(context)),
              const SizedBox(height: 18),
              _buildNav(context),
              const SizedBox(height: 12),
              _StepDots(total: _loadingStep, current: _step),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = context.runninPalette;
    final canGoBack = _step > 0 && _step != _loadingStep;

    return Row(
      children: [
        if (canGoBack)
          OutlinedButton(
            onPressed: _submitting
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    setState(() => _step--);
                  },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(86, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('< VOLTAR'),
          )
        else
          const SizedBox(width: 86, height: 38),
        const Spacer(),
        Text('RUNNIN', style: context.runninType.labelMd),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          color: palette.primary,
          child: Text(
            '.AI',
            style: context.runninType.labelMd.copyWith(
              color: palette.background,
              fontSize: 9,
              fontWeight: FontWeight.w900,
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
        return _StepLevel(
          selected: _data.level,
          levels: _levels,
          onSelect: (v) {
            HapticFeedback.selectionClick();
            setState(() => _data.level = v);
          },
        );
      case 1:
        return _StepIdentity(
          nameController: _nameCtrl,
          birthDateController: _birthDateCtrl,
          onNameChanged: (v) => _data.name = v,
          onBirthDateChanged: (v) => _data.birthDate = v,
        );
      case 2:
        return _StepBody(
          weightController: _weightCtrl,
          heightController: _heightCtrl,
          onWeightChanged: (v) => _data.weight = v,
          onHeightChanged: (v) => _data.height = v,
        );
      case 3:
        return _StepMedicalConditions(
          selected: _data.medicalConditions,
          options: _medicalOptions,
          otherController: _medicalOtherCtrl,
          onToggle: (v) {
            HapticFeedback.selectionClick();
            setState(() {
              if (_data.medicalConditions.contains(v)) {
                _data.medicalConditions.remove(v);
              } else {
                _data.medicalConditions.add(v);
              }
            });
          },
          onAddOther: () {
            final v = _medicalOtherCtrl.text.trim();
            if (v.isEmpty) return;
            HapticFeedback.lightImpact();
            setState(() {
              _data.medicalConditions.add(v);
              _medicalOtherCtrl.clear();
            });
          },
        );
      case 4:
        return _StepFrequency(
          frequency: _data.frequency,
          onFreqChange: (v) {
            HapticFeedback.selectionClick();
            setState(() => _data.frequency = v);
          },
        );
      case 5:
        return _StepGoal(
          goals: _goals,
          selectedGoal: _data.goal,
          onGoalSelect: (v) {
            HapticFeedback.selectionClick();
            setState(() => _data.goal = v);
          },
        );
      case 6:
        return _StepPaceTarget(
          selected: _data.paceTarget,
          options: _paceOptions,
          onSelect: (v) {
            HapticFeedback.selectionClick();
            setState(() => _data.paceTarget = v);
          },
        );
      case 7:
        return _StepRoutine(
          preferredRunTime: _data.preferredRunTime,
          runTimeOptions: _runTimeOptions,
          wakeUpTime: _data.wakeUpTime,
          sleepTime: _data.sleepTime,
          wakeOptions: _wakeOptions,
          sleepOptions: _sleepOptions,
          onRunTimeChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _data.preferredRunTime = v);
          },
          onWakeUpChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _data.wakeUpTime = v);
          },
          onSleepChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _data.sleepTime = v);
          },
        );
      case 8:
        return _StepWearable(
          selected: _data.hasWearable,
          options: _wearableOptions,
          onSelect: (v) {
            HapticFeedback.selectionClick();
            setState(() => _data.hasWearable = v);
          },
        );
      case _loadingStep:
        return const _StepGeneratingPlan();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNav(BuildContext context) {
    final palette = context.runninPalette;
    if (_step == _loadingStep) return const SizedBox.shrink();

    final isLastStep = _step == _loadingStep - 1;
    final label = isLastStep ? 'CRIAR MEU PLANO' : 'PR\u00d3XIMO';

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _canProceed()
                ? (isLastStep
                    ? _submit
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() => _step++);
                      })
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
        if (_step == 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pode pular se preferir. Voc\u00ea pode adicionar depois no Perfil.',
              style: context.runninType.bodySm.copyWith(
                color: palette.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (_error != null || _getValidationError() != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Text(
                  _error ?? _getValidationError()!,
                  style: TextStyle(color: palette.error, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                if (_error != null &&
                    (_error!.contains('Tente novamente') ||
                        _error!.contains('novamente')))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: _submit,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'TENTAR NOVAMENTE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  bool _canProceed() {
    if (_submitting) return false;
    switch (_step) {
      case 1:
        return _nameCtrl.text.trim().isNotEmpty &&
            _isValidBirthDate(_birthDateCtrl.text.trim());
      case 2:
        return _weightCtrl.text.trim().isNotEmpty &&
            _heightCtrl.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  String? _getValidationError() {
    switch (_step) {
      case 1:
        if (_nameCtrl.text.isNotEmpty &&
            _nameCtrl.text.trim().isEmpty) {
          return 'Digite seu nome.';
        }
        if (_birthDateCtrl.text.isNotEmpty &&
            !_isValidBirthDate(_birthDateCtrl.text.trim())) {
          return _getDateValidationError(_birthDateCtrl.text.trim());
        }
        return null;
      case 2:
        if (_weightCtrl.text.isEmpty || _heightCtrl.text.isEmpty) {
          return 'Preencha peso e altura.';
        }
        return null;
      default:
        return null;
    }
  }

  String? _getDateValidationError(String value) {
    if (value.length < 10) {
      return 'Data incompleta. Use formato dd/mm/aaaa.';
    }

    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match == null) {
      return 'Data inválida. Use formato dd/mm/aaaa.';
    }

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);

    if (day == null || month == null || year == null) {
      return 'Data inválida.';
    }

    try {
      final date = DateTime(year, month, day);
      final isExactDate =
          date.year == year && date.month == month && date.day == day;

      if (!isExactDate) {
        return 'Data não existe no calendário.';
      }

      final now = DateTime.now();
      final age = now.year - year;

      if (age < 8) {
        return 'Idade mínima: 8 anos.';
      }

      if (age > 100) {
        return 'Verifique o ano de nascimento.';
      }

      return null;
    } catch (_) {
      return 'Data inválida.';
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
}

class _StepCode extends StatelessWidget {
  final String value;
  const _StepCode(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      '// $value',
      style: context.runninType.labelMd.copyWith(
        color: context.runninPalette.primary,
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int total;
  final int current;
  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final active = index == current.clamp(0, total - 1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: active ? 14 : 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          color: active ? palette.primary : palette.border,
        );
      }),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String value;
  const _FieldLabel(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        fontSize: 10,
        color: context.runninPalette.muted,
        letterSpacing: 0.15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _StepLevel extends StatelessWidget {
  final String selected;
  final List<(String, String, String)> levels;
  final ValueChanged<String> onSelect;

  const _StepLevel({
    required this.selected,
    required this.levels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepCode('ASSESSMENT_01'),
          const SizedBox(height: 12),
          Text(
            'Qual seu n\u00edvel atual?',
            style: context.runninType.displayMd,
          ),
          const SizedBox(height: 10),
          Text(
            'O Coach adapta intensidade, volume e progress\u00e3o ao seu n\u00edvel.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 32),
          ...levels.map((level) {
            final isSelected = selected == level.$1;
            return GestureDetector(
              onTap: () => onSelect(level.$1),
              child: AppPanel(
                margin: const EdgeInsets.only(bottom: 8),
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.08)
                    : null,
                borderColor: isSelected ? palette.primary : palette.border,
                child: Text(
                  '${level.$2} \u2014 ${level.$3}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? palette.primary : palette.text,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepIdentity extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController birthDateController;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onBirthDateChanged;

  const _StepIdentity({
    required this.nameController,
    required this.birthDateController,
    required this.onNameChanged,
    required this.onBirthDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepCode('ASSESSMENT_02'),
          const SizedBox(height: 12),
          Text('Como te chamo?', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Nome e data de nascimento \u2014 o Coach usa para personalizar comunica\u00e7\u00e3o e calcular zonas card\u00edacas com precis\u00e3o.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          _FieldLabel('SEU NOME'),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: onNameChanged,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
            decoration: InputDecoration(
              hintText: 'Ex: Lucas',
              hintStyle: TextStyle(color: palette.border, fontSize: 22),
            ),
          ),
          const SizedBox(height: 28),
          _FieldLabel('DATA DE NASCIMENTO'),
          const SizedBox(height: 8),
          TextField(
            controller: birthDateController,
            keyboardType: TextInputType.number,
            onChanged: onBirthDateChanged,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
              _DateTextInputFormatter(),
            ],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
            decoration: InputDecoration(
              hintText: 'dd/mm/aaaa',
              hintStyle: TextStyle(color: palette.border, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final trimmed = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      buffer.write(trimmed[i]);
      if ((i == 1 || i == 3) && i != trimmed.length - 1) {
        buffer.write('/');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _StepBody extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController heightController;
  final ValueChanged<String> onWeightChanged;
  final ValueChanged<String> onHeightChanged;

  const _StepBody({
    required this.weightController,
    required this.heightController,
    required this.onWeightChanged,
    required this.onHeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepCode('ASSESSMENT_03'),
          const SizedBox(height: 12),
          Text('Peso e altura', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Usamos para calcular gasto cal\u00f3rico, zonas card\u00edacas e carga de impacto nas articula\u00e7\u00f5es.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _MetricInput(
                  label: 'PESO (KG)',
                  controller: weightController,
                  onChanged: onWeightChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricInput(
                  label: 'ALTURA (CM)',
                  controller: heightController,
                  onChanged: onHeightChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const _MetricInput({
    required this.label,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepMedicalConditions extends StatelessWidget {
  final Set<String> selected;
  final List<String> options;
  final TextEditingController otherController;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddOther;

  const _StepMedicalConditions({
    required this.selected,
    required this.options,
    required this.otherController,
    required this.onToggle,
    required this.onAddOther,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final customOptions = selected.where((item) => !options.contains(item));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepCode('ASSESSMENT_04'),
          const SizedBox(height: 12),
          Text('Informa\u00e7\u00f5es de sa\u00fade',
              style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Opcional, mas importante. Selecione condi\u00e7\u00f5es relevantes para que o Coach ajuste intensidade, alertas e limites de seguran\u00e7a.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          AppPanel(
            color: palette.secondary.withValues(alpha: 0.06),
            borderColor: palette.secondary.withValues(alpha: 0.16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTag(label: 'COACH.AI', color: palette.secondary),
                const SizedBox(height: 12),
                Text(
                  'Vou avaliar todas as suas informa\u00e7\u00f5es para montar um programa de treino seguro e personalizado. Se voc\u00ea toma medica\u00e7\u00e3o que altera frequ\u00eancia card\u00edaca, por exemplo, ajusto as zonas de BPM automaticamente.',
                  style: context.runninType.bodySm.copyWith(
                    color: palette.text.withValues(alpha: 0.86),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...options.map(
                (option) => _ConditionChip(
                  label: option,
                  selected: selected.contains(option),
                  onTap: () => onToggle(option),
                ),
              ),
              ...customOptions.map(
                (option) => _ConditionChip(
                  label: option,
                  selected: true,
                  onTap: () => onToggle(option),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: otherController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAddOther(),
                  decoration: const InputDecoration(
                    hintText:
                        'Adicionar outra condi\u00e7\u00e3o ou medica\u00e7\u00e3o',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 48,
                child: OutlinedButton(
                  onPressed: onAddOther,
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: Icon(Icons.add, color: palette.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.1)
              : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: context.runninType.bodySm.copyWith(
            color: selected ? palette.primary : palette.text,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StepFrequency extends StatelessWidget {
  final int frequency;
  final ValueChanged<int> onFreqChange;

  const _StepFrequency({required this.frequency, required this.onFreqChange});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    const options = [2, 3, 4, 5, 6];
    const labels = <int, String>{
      2: 'Base leve',
      3: 'Const\u00e2ncia',
      4: 'Equil\u00edbrio',
      5: 'Performance',
      6: 'Alta carga',
    };
    final coachNotes = <int, String>{
      2: '\u00d3timo para come\u00e7ar com const\u00e2ncia sem pesar a rotina. Vamos priorizar adapta\u00e7\u00e3o e recupera\u00e7\u00e3o.',
      3: 'Boa frequ\u00eancia para criar base com seguran\u00e7a. J\u00e1 d\u00e1 para evoluir volume e ritmo aos poucos.',
      4: 'Excelente equil\u00edbrio entre progresso e recupera\u00e7\u00e3o. Costuma render planos bem completos.',
      5: 'Frequ\u00eancia forte. O Coach vai distribuir carga com mais precis\u00e3o para evitar excesso.',
      6: 'Rotina de alto compromisso. Vamos controlar intensidade para sustentar consist\u00eancia.',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepCode('ASSESSMENT_05'),
              const SizedBox(height: 12),
              Text(
                'Quantas vezes por semana?',
                style: context.runninType.displayMd,
              ),
              const SizedBox(height: 10),
              Text(
                'O Coach distribui sess\u00f5es com descanso adequado entre cada corrida.',
                style: TextStyle(color: palette.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: options.map((option) {
                  final isSelected = frequency == option;
                  return GestureDetector(
                    onTap: () => onFreqChange(option),
                    child: SizedBox(
                      width: itemWidth,
                      child: AppPanel(
                        color: isSelected
                            ? palette.primary.withValues(alpha: 0.08)
                            : null,
                        borderColor:
                            isSelected ? palette.primary : palette.border,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${option}x',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? palette.primary
                                    : palette.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              labels[option]!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? palette.primary.withValues(alpha: 0.85)
                                    : palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              AppPanel(
                color: palette.surfaceAlt,
                borderColor: palette.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTag(label: 'COACH.AI', color: palette.secondary),
                    const SizedBox(height: 12),
                    Text(
                      coachNotes[frequency]!,
                      style: TextStyle(
                        color: palette.text.withValues(alpha: 0.82),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepGoal extends StatelessWidget {
  final List<String> goals;
  final String selectedGoal;
  final ValueChanged<String> onGoalSelect;

  const _StepGoal({
    required this.goals,
    required this.selectedGoal,
    required this.onGoalSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepCode('ASSESSMENT_06'),
          const SizedBox(height: 12),
          Text(
            'Qual sua meta principal?',
            style: context.runninType.displayMd,
          ),
          const SizedBox(height: 10),
          Text(
            'O Coach monta periodiza\u00e7\u00e3o, volume e progress\u00e3o com base no seu objetivo.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          ...goals.map((goal) {
            final isSelected = selectedGoal == goal;
            return GestureDetector(
              onTap: () => onGoalSelect(goal),
              child: AppPanel(
                margin: const EdgeInsets.only(bottom: 8),
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.08)
                    : null,
                borderColor: isSelected ? palette.primary : palette.border,
                child: Text(
                  goal,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? palette.primary : palette.text,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepPaceTarget extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelect;

  const _StepPaceTarget({
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepCode('ASSESSMENT_07'),
          const SizedBox(height: 12),
          Text('Voc\u00ea tem um pace alvo?',
              style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'N\u00e3o se preocupe se n\u00e3o sabe \u2014 o Coach avalia na primeira corrida e calibra tudo automaticamente.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          ...options.map((option) {
            final isSelected = selected == option;
            return GestureDetector(
              onTap: () => onSelect(option),
              child: AppPanel(
                margin: const EdgeInsets.only(bottom: 8),
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.08)
                    : null,
                borderColor: isSelected ? palette.primary : palette.border,
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? palette.primary : palette.text,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepRoutine extends StatelessWidget {
  final String preferredRunTime;
  final List<(String, String, String, String)> runTimeOptions;
  final String wakeUpTime;
  final String sleepTime;
  final List<String> wakeOptions;
  final List<String> sleepOptions;
  final ValueChanged<String> onRunTimeChanged;
  final ValueChanged<String> onWakeUpChanged;
  final ValueChanged<String> onSleepChanged;

  const _StepRoutine({
    required this.preferredRunTime,
    required this.runTimeOptions,
    required this.wakeUpTime,
    required this.sleepTime,
    required this.wakeOptions,
    required this.sleepOptions,
    required this.onRunTimeChanged,
    required this.onWakeUpChanged,
    required this.onSleepChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepCode('ASSESSMENT_08'),
          const SizedBox(height: 12),
          Text('Rotina e hor\u00e1rio',
              style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'O Coach usa seu hor\u00e1rio para calcular janela metab\u00f3lica ideal, lembretes de hidrata\u00e7\u00e3o, preparo nutricional e sugest\u00e3o de melhor hora para correr.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          const _FieldLabel('QUANDO PREFERE CORRER?'),
          const SizedBox(height: 12),
          ...runTimeOptions.map((opt) {
            final isSelected = preferredRunTime == opt.$1;
            return GestureDetector(
              onTap: () => onRunTimeChanged(opt.$1),
              child: AppPanel(
                margin: const EdgeInsets.only(bottom: 8),
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.08)
                    : null,
                borderColor: isSelected ? palette.primary : palette.border,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.$2,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  isSelected ? palette.primary : palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      opt.$4,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('ACORDA'),
                    const SizedBox(height: 8),
                    _TimeSelector(
                      options: wakeOptions,
                      selected: wakeUpTime,
                      onSelect: onWakeUpChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('DORME'),
                    const SizedBox(height: 8),
                    _TimeSelector(
                      options: sleepOptions,
                      selected: sleepTime,
                      onSelect: onSleepChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _TimeSelector({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      children: options.map((opt) {
        final isSelected = selected == opt;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? palette.primary.withValues(alpha: 0.1)
                  : palette.surface,
              border: Border.all(
                color: isSelected ? palette.primary : palette.border,
              ),
            ),
            child: Text(
              opt,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? palette.primary : palette.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StepWearable extends StatelessWidget {
  final bool selected;
  final List<(bool, String, String)> options;
  final ValueChanged<bool> onSelect;

  const _StepWearable({
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepCode('ASSESSMENT_09'),
          const SizedBox(height: 12),
          Text('Conectar wearable?',
              style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Dados de BPM, sono e atividade permitem que o Coach personalize com mais precis\u00e3o.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          ...options.map((option) {
            final isSelected = selected == option.$1;
            return GestureDetector(
              onTap: () => onSelect(option.$1),
              child: AppPanel(
                margin: const EdgeInsets.only(bottom: 8),
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.08)
                    : null,
                borderColor: isSelected ? palette.primary : palette.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.$2,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? palette.primary : palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(option.$3,
                        style: TextStyle(color: palette.muted)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
          AppPanel(
            color: palette.secondary.withValues(alpha: 0.06),
            borderColor: palette.secondary.withValues(alpha: 0.16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTag(label: 'COACH.AI', color: palette.secondary),
                const SizedBox(height: 12),
                Text(
                  'Tenho tudo que preciso \u2014 incluindo sua rotina de sono e hor\u00e1rio preferido. Vou calcular a janela metab\u00f3lica ideal para cada tipo de treino, enviar lembretes de hidrata\u00e7\u00e3o e preparo nutricional, e sugerir o melhor hor\u00e1rio com base no seu padr\u00e3o de sono.',
                  style: TextStyle(
                    color: palette.text.withValues(alpha: 0.82),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tem exames m\u00e9dicos recentes?\nTestes ergom\u00e9tricos, exames de sangue e laudos m\u00e9dicos permitem que eu calibre zonas card\u00edacas com FC m\u00e1x real, monitore ferritina e identifique restri\u00e7\u00f5es. Ap\u00f3s criar seu plano, acesse Perfil \u2192 Sa\u00fade \u2192 Exames.',
                  style: TextStyle(
                    color: palette.muted,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepGeneratingPlan extends StatelessWidget {
  const _StepGeneratingPlan();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: palette.primary,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'GERANDO SEU PLANO',
            style: type.displaySm,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'O Coach est\u00e1 montando sua periodiza\u00e7\u00e3o\ncom base no seu perfil.',
            style: type.bodyMd.copyWith(color: palette.muted, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
