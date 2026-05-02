import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';

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

  static const _totalSteps = 7; // 0–5 dados + 6 loading

  int _step = 0;
  String _level = 'iniciante';
  String _goal = 'Completar 10K';
  int _frequency = 4;
  bool _hasWearable = false;
  String? _error;

  static const _levels = [
    ('iniciante', 'Iniciante', 'Nunca corri ou estou voltando agora'),
    ('intermediario', 'Intermediário', 'Corro regularmente durante a semana'),
    ('avancado', 'Avançado', 'Já treino com estrutura e metas específicas'),
  ];

  static const _goals = [
    'Saúde e bem-estar',
    'Perder peso',
    'Completar 5K',
    'Completar 10K',
    'Meia maratona (21K)',
    'Maratona (42K)',
  ];

  static const _wearableOptions = [
    (
      true,
      'Tenho wearable',
      'Vamos marcar a preferencia, mas a integracao ainda precisa ser conectada',
    ),
    (false, 'Depois', 'Nenhum dado sera tratado como conectado por enquanto'),
  ];

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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canProceed()) return;
    // Vai para o passo de loading antes de chamar a API
    setState(() {
      _step = _totalSteps - 1;
      _error = null;
    });
    _doSubmit();
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
        hasWearable: _hasWearable,
      );
      markOnboardingDone();
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao salvar perfil. Tente novamente.';
          _step = _totalSteps - 2; // volta ao último passo de dados
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(
                  _totalSteps,
                  (index) => Expanded(
                    child: Container(
                      height: 2,
                      margin: EdgeInsets.only(
                        right: index < _totalSteps - 1 ? 4 : 0,
                      ),
                      color: index <= _step ? palette.primary : palette.border,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(child: _buildStep(context)),
              const SizedBox(height: 24),
              _buildNav(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _StepIdentity(
          nameController: _nameCtrl,
          birthDateController: _birthDateCtrl,
        );
      case 1:
        return _StepLevel(
          selected: _level,
          levels: _levels,
          onSelect: (value) => setState(() => _level = value),
        );
      case 2:
        return _StepBody(
          weightController: _weightCtrl,
          heightController: _heightCtrl,
        );
      case 3:
        return _StepGoal(
          goals: _goals,
          selectedGoal: _goal,
          onGoalSelect: (value) => setState(() => _goal = value),
        );
      case 4:
        return _StepFrequency(
          frequency: _frequency,
          onFreqChange: (value) => setState(() => _frequency = value),
        );
      case 5:
        return _StepWearable(
          selected: _hasWearable,
          options: _wearableOptions,
          onSelect: (value) => setState(() => _hasWearable = value),
        );
      case 6:
        return const _StepGeneratingPlan();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNav(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: palette.error, fontSize: 13),
            ),
          ),
        // Passo de loading não mostra botões
        if (_step < _totalSteps - 1) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _canProceed()
                  ? (_step < _totalSteps - 2 ? _nextStep : _submit)
                  : null,
              child: Text(
                _step < _totalSteps - 2 ? 'PRÓXIMO' : 'CRIAR MEU PLANO',
              ),
            ),
          ),
          if (_step > 0)
            TextButton(
              onPressed: () => setState(() => _step--),
              child: Text(
                'VOLTAR',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty &&
            _isValidBirthDate(_birthDateCtrl.text.trim());
      case 2:
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

  void _handleFieldChange() {
    if (!mounted) return;
    setState(() {
      _error = null;
    });
  }

  void _nextStep() => setState(() => _step++);
}

class _StepIdentity extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController birthDateController;

  const _StepIdentity({
    required this.nameController,
    required this.birthDateController,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ETAPA 1 DE 6',
            style: TextStyle(
              fontSize: 12,
              color: palette.primary,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 12),
          Text('Como te chamo?', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Nome e data de nascimento ajudam o Coach a personalizar comunicação, zonas e progressão.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          Text(
            'SEU NOME',
            style: TextStyle(
              fontSize: 10,
              color: palette.muted,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
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
          Text(
            'DATA DE NASCIMENTO',
            style: TextStyle(
              fontSize: 10,
              color: palette.muted,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: birthDateController,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ETAPA 2 DE 6',
          style: TextStyle(
            fontSize: 12,
            color: palette.primary,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 12),
        Text('Qual seu nível atual?', style: context.runninType.displayMd),
        const SizedBox(height: 10),
        Text(
          'O Coach adapta intensidade, volume e progressão ao seu momento.',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.$2,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? palette.primary : palette.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(level.$3, style: TextStyle(color: palette.muted)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StepBody extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController heightController;

  const _StepBody({
    required this.weightController,
    required this.heightController,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ETAPA 3 DE 6',
            style: TextStyle(
              fontSize: 12,
              color: palette.primary,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 12),
          Text('Peso e altura', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Usamos isso para estimar gasto calórico, zonas e carga de impacto.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _MetricInput(
                  label: 'PESO (KG)',
                  controller: weightController,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricInput(
                  label: 'ALTURA (CM)',
                  controller: heightController,
                ),
              ),
            ],
          ),
        ],
      ),
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
          Text(
            'ETAPA 4 DE 6',
            style: TextStyle(
              fontSize: 12,
              color: palette.primary,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 12),
          Text('Qual sua meta principal?', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'A periodização nasce do objetivo certo.',
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
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      3: 'Constância',
      4: 'Equilíbrio',
      5: 'Performance',
      6: 'Alta carga',
    };
    final coachNotes = <int, String>{
      2: 'Ótimo para começar com constância sem pesar a rotina. Vamos priorizar adaptação e recuperação.',
      3: 'Boa frequência para criar base com segurança. Já dá para evoluir volume e ritmo aos poucos.',
      4: 'Excelente equilíbrio entre progresso e recuperação. Costuma render planos bem completos.',
      5: 'Frequência forte. O Coach vai distribuir carga com mais precisão para evitar excesso.',
      6: 'Rotina de alto compromisso. Vamos precisar controlar intensidade para sustentar consistência.',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ETAPA 5 DE 6',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.primary,
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Quantas vezes por semana?',
                style: context.runninType.displayMd,
              ),
              const SizedBox(height: 10),
              Text(
                'O Coach distribui estímulo e descanso com base nessa rotina.',
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
                        borderColor: isSelected
                            ? palette.primary
                            : palette.border,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ETAPA 6 DE 6',
          style: TextStyle(
            fontSize: 12,
            color: palette.primary,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 12),
        Text('Conectar wearable?', style: context.runninType.displayMd),
        const SizedBox(height: 10),
        Text(
          'Por enquanto isso registra apenas uma preferencia. Dados reais aparecem depois que houver integracao ou corrida com BPM.',
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
                  Text(option.$3, style: TextStyle(color: palette.muted)),
                ],
              ),
            ),
          );
        }),
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
                'Depois deste onboarding, a próxima etapa é integrar rotina, saúde detalhada e exames no perfil.',
                style: TextStyle(
                  color: palette.text.withValues(alpha: 0.82),
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

class _MetricInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _MetricInput({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: palette.muted,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
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
            'O Coach está montando sua periodização\ncom base no seu perfil.',
            style: type.bodyMd.copyWith(color: palette.muted, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
