import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/figma/figma_coach_ai_block.dart';
import 'package:runnin/shared/widgets/figma/figma_form_field_label.dart';
import 'package:runnin/shared/widgets/figma/figma_form_text_field.dart';
import 'package:runnin/shared/widgets/figma/figma_selection_button.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/gamification_stats_row.dart';
import 'package:runnin/shared/widgets/user_profile_header.dart';

class _ProfileCoachAICard extends StatefulWidget {
  const _ProfileCoachAICard();

  @override
  State<_ProfileCoachAICard> createState() => _ProfileCoachAICardState();
}

class _ProfileCoachAICardState extends State<_ProfileCoachAICard> {
  bool _expanded = false;

  String _monthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: FigmaCoachAIBlock(
          variant: CoachAIBlockVariant.appGeneral,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FigmaCoachAIBreadcrumb(action: 'FECHAMENTO MENSAL'),
                        const SizedBox(height: 2),
                        Text(
                          'Como foi o seu mês de treino?',
                          maxLines: _expanded ? null : 1,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            height: 16.5 / 11,
                            fontWeight: FontWeight.w500,
                            color: FigmaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      '▼',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        height: 1,
                        color: FigmaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 14),
                Text(
                  'Você completou ${DateTime.now().month == 1 ? 'Janeiro' : _monthName(DateTime.now().month - 1)}. O Coach.AI preparou um resumo com suas métricas, zonas de esforço e evolução. Deseja ver o fechamento completo?',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    height: 18 / 11,
                    fontWeight: FontWeight.w400,
                    color: FigmaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FigmaSelectionButton(
                        label: 'VER RESUMO',
                        selected: true,
                        onTap: () => context.push('/training'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FigmaSelectionButton(
                      label: 'IGNORAR',
                      selected: false,
                      onTap: () => setState(() => _expanded = false),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final bool initialEditing;

  const ProfilePage({super.key, this.initialEditing = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _runDatasource = RunRemoteDatasource();
  final _userDatasource = UserRemoteDatasource();

  final _nameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _restingBpmCtrl = TextEditingController();
  final _maxBpmCtrl = TextEditingController();

  List<Run>? _runs;
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String _level = 'iniciante';
  String _goal = 'Completar 10K';
  int _frequency = 4;
  bool _hasWearable = false;
  String _gender = 'na';
  String _runPeriod = 'manha';
  String? _wakeTime;
  String? _sleepTime;
  String? _error;
  String? _saveMessage;

  static const _levels = [
    ('iniciante', 'Iniciante'),
    ('intermediario', 'Intermediário'),
    ('avancado', 'Avançado'),
  ];

  static const _goals = [
    'Saúde e bem-estar',
    'Perder peso',
    'Completar 5K',
    'Completar 10K',
    'Meia maratona (21K)',
    'Maratona (42K)',
  ];

  static const _frequencyOptions = [2, 3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    _editing = widget.initialEditing;
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _restingBpmCtrl.dispose();
    _maxBpmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _runDatasource.listRuns(limit: 200),
        _userDatasource.getMe(),
      ]);

      final runs = (results[0] as List<Run>)
          .where((run) => run.status == 'completed')
          .toList();
      final profile = results[1] as UserProfile?;

      if (!mounted) return;

      _hydrateForm(profile);
      setState(() {
        _runs = runs;
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar perfil.';
        _loading = false;
      });
    }
  }

  void _hydrateForm(UserProfile? profile) {
    _nameCtrl.text = profile?.name ?? '';
    _birthDateCtrl.text = profile?.birthDate ?? '';
    _weightCtrl.text = profile?.weight ?? '';
    _heightCtrl.text = profile?.height ?? '';
    _restingBpmCtrl.text = profile?.restingBpm?.toString() ?? '';
    _maxBpmCtrl.text = profile?.maxBpm?.toString() ?? '';
    _level = profile?.level ?? 'iniciante';
    _goal = profile?.goal ?? 'Completar 10K';
    _frequency = profile?.frequency ?? 4;
    _hasWearable = profile?.hasWearable ?? false;
    _gender = profile?.gender ?? 'na';
    _runPeriod = profile?.runPeriod ?? 'manha';
    _wakeTime = profile?.wakeTime;
    _sleepTime = profile?.sleepTime;
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
      _saveMessage = null;
      _error = null;
    });

    final resting = int.tryParse(_restingBpmCtrl.text.trim());
    final maxBpm = int.tryParse(_maxBpmCtrl.text.trim());
    if (resting != null && maxBpm != null && maxBpm <= resting) {
      setState(() {
        _saving = false;
        _error = 'FC máxima deve ser maior que FC repouso.';
      });
      return;
    }
    if (_wakeTime != null && _wakeTime == _sleepTime) {
      setState(() {
        _saving = false;
        _error = 'Horário de acordar e dormir não podem ser iguais.';
      });
      return;
    }

    try {
      final updated = await _userDatasource.patchMe(
        name: _nameCtrl.text.trim(),
        birthDate: _birthDateCtrl.text.trim().isEmpty
            ? ''
            : _birthDateCtrl.text.trim(),
        weight: _weightCtrl.text.trim().isEmpty ? '' : _weightCtrl.text.trim(),
        height: _heightCtrl.text.trim().isEmpty ? '' : _heightCtrl.text.trim(),
        level: _level,
        goal: _goal,
        frequency: _frequency,
        hasWearable: _hasWearable,
        gender: _gender,
        runPeriod: _runPeriod,
        wakeTime: _wakeTime,
        sleepTime: _sleepTime,
        restingBpm: resting,
        maxBpm: maxBpm,
        onboarded: true,
      );

      if (!mounted) return;

      setState(() {
        _profile = updated;
        _editing = false;
        _saving = false;
        _saveMessage = 'Perfil atualizado.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Erro ao salvar perfil.';
      });
    }
  }

  void _cancelEdit() {
    _hydrateForm(_profile);
    setState(() {
      _editing = false;
      _saveMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    final totalRuns = _runs?.length ?? 0;
    final totalDistKm =
        (_runs?.fold(0.0, (sum, run) => sum + run.distanceM) ?? 0) / 1000;
    final totalXp =
        _runs?.fold(0, (sum, run) => sum + (run.xpEarned ?? 0)) ?? 0;
    final levelNumber = (totalXp / 500).floor() + 1;

    int calculateStreak(List<Run> runs) {
      if (runs.isEmpty) return 0;

      final sortedRuns = runs..sort((a, b) {
        final dateA = DateTime.parse(a.createdAt);
        final dateB = DateTime.parse(b.createdAt);
        return dateB.compareTo(dateA);
      });

      if (sortedRuns.isEmpty) return 0;

      final lastRunDate = DateTime.parse(sortedRuns.first.createdAt);
      int streak = 1;
      var currentCheckDate =
          DateTime(lastRunDate.year, lastRunDate.month, lastRunDate.day - 1);

      for (int i = 1; i < sortedRuns.length; i++) {
        final runDate =
            DateTime.parse(sortedRuns[i].createdAt).toLocal();
        currentCheckDate = currentCheckDate.toLocal();

        if (runDate.year == currentCheckDate.year &&
            runDate.month == currentCheckDate.month &&
            runDate.day == currentCheckDate.day) {
          streak++;
          currentCheckDate = DateTime(
              currentCheckDate.year, currentCheckDate.month, currentCheckDate.day - 1);
        } else if (runDate.isBefore(currentCheckDate)) {
          break;
        }
      }

      return streak;
    }

    final streak = calculateStreak(_runs ?? []);
    final badges = (totalXp / 100).floor();

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FigmaTopNav(breadcrumb: 'EDITAR PERFIL', showBackButton: true),
            const SizedBox(height: 24),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: palette.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : _error != null && _profile == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: palette.muted)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _loadProfile,
                            child: const Text('TENTAR NOVAMENTE'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserProfileHeader(
                            userName: _profile?.name.isNotEmpty == true
                                ? _profile!.name
                                : (firebaseUser?.displayName ?? 'Corredor'),
                            levelNumber: levelNumber,
                            isPremium: !(firebaseUser?.isAnonymous ?? true),
                            totalRuns: totalRuns,
                            totalDistanceKm: totalDistKm,
                          ),
                          if (firebaseUser?.isAnonymous ?? false) ...[
                            const SizedBox(height: 12),
                            _AnonPromoBanner(onTap: () => context.push('/profile/access')),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'CORRIDAS',
                                  value: '$totalRuns',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatCard(
                                  label: 'DISTÂNCIA',
                                  value: totalDistKm >= 1
                                      ? '${totalDistKm.toStringAsFixed(1)} km'
                                      : '${(totalDistKm * 1000).toStringAsFixed(0)} m',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatCard(
                                  label: 'NÍVEL',
                                  value: '$levelNumber',
                                  accent: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GamificationStatsRow(
                            streak: StatData(
                              label: 'STREAK',
                              value: '$streak',
                            ),
                            xp: StatData(
                              label: 'XP',
                              value: '$totalXp',
                              accent: true,
                            ),
                            badges: StatData(
                              label: 'BADGES',
                              value: '$badges',
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _FieldLabel(label: 'PERFIL'),
                          const SizedBox(height: 8),
                          _ProfileEditor(
                            nameController: _nameCtrl,
                            birthDateController: _birthDateCtrl,
                            weightController: _weightCtrl,
                            heightController: _heightCtrl,
                            restingBpmController: _restingBpmCtrl,
                            maxBpmController: _maxBpmCtrl,
                            selectedLevel: _level,
                            selectedGoal: _goal,
                            frequency: _frequency,
                            hasWearable: _hasWearable,
                            gender: _gender,
                            runPeriod: _runPeriod,
                            wakeTime: _wakeTime,
                            sleepTime: _sleepTime,
                            levels: _levels,
                            goals: _goals,
                            frequencyOptions: _frequencyOptions,
                            enabled: _editing,
                            onLevelChanged: (value) =>
                                setState(() => _level = value),
                            onGoalChanged: (value) =>
                                setState(() => _goal = value),
                            onFrequencyChanged: (value) =>
                                setState(() => _frequency = value),
                            onWearableChanged: (value) =>
                                setState(() => _hasWearable = value),
                            onGenderChanged: (value) =>
                                setState(() => _gender = value),
                            onRunPeriodChanged: (value) =>
                                setState(() => _runPeriod = value),
                            onWakeTimeChanged: (value) =>
                                setState(() => _wakeTime = value),
                            onSleepTimeChanged: (value) =>
                                setState(() => _sleepTime = value),
                          ),
                          if (_saveMessage != null ||
                              (_error != null && _profile != null)) ...[
                            const SizedBox(height: 12),
                            AppPanel(
                              padding: const EdgeInsets.all(12),
                              color:
                                  (_saveMessage != null
                                          ? palette.primary
                                          : palette.error)
                                      .withValues(alpha: 0.08),
                              borderColor:
                                  (_saveMessage != null
                                          ? palette.primary
                                          : palette.error)
                                      .withValues(alpha: 0.35),
                              child: Text(
                                _saveMessage ?? _error ?? '',
                                style: TextStyle(
                                  color: _saveMessage != null
                                      ? palette.primary
                                      : palette.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          if (_editing) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _saving ? null : _cancelEdit,
                                    child: const Text('CANCELAR'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _saveProfile,
                                    child: _saving
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: palette.background,
                                            ),
                                          )
                                        : const Text('SALVAR'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // PLANO, SKIN, TAMANHO DA FONTE foram movidos:
                          // - PLANO/upgrade vive no /paywall (acesso via menu).
                          // - SKIN + TAMANHO DA FONTE viraram settings em
                          //   /profile/settings/units (a expor depois).
                          // Edit profile mantém só dados pessoais + conta.
                          const SizedBox(height: 32),
                          const _FieldLabel(label: 'CONTA'),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => FirebaseAuth.instance.signOut(),
                            child: AppPanel(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.logout,
                                    size: 16,
                                    color: palette.error,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'SAIR',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: palette.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditor extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController birthDateController;
  final TextEditingController weightController;
  final TextEditingController heightController;
  final TextEditingController restingBpmController;
  final TextEditingController maxBpmController;
  final String selectedLevel;
  final String selectedGoal;
  final int frequency;
  final bool hasWearable;
  final String gender;
  final String runPeriod;
  final String? wakeTime;
  final String? sleepTime;
  final List<(String, String)> levels;
  final List<String> goals;
  final List<int> frequencyOptions;
  final bool enabled;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onGoalChanged;
  final ValueChanged<int> onFrequencyChanged;
  final ValueChanged<bool> onWearableChanged;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<String> onRunPeriodChanged;
  final ValueChanged<String?> onWakeTimeChanged;
  final ValueChanged<String?> onSleepTimeChanged;

  const _ProfileEditor({
    required this.nameController,
    required this.birthDateController,
    required this.weightController,
    required this.heightController,
    required this.restingBpmController,
    required this.maxBpmController,
    required this.selectedLevel,
    required this.selectedGoal,
    required this.frequency,
    required this.hasWearable,
    required this.gender,
    required this.runPeriod,
    required this.wakeTime,
    required this.sleepTime,
    required this.levels,
    required this.goals,
    required this.frequencyOptions,
    required this.enabled,
    required this.onLevelChanged,
    required this.onGoalChanged,
    required this.onFrequencyChanged,
    required this.onWearableChanged,
    required this.onGenderChanged,
    required this.onRunPeriodChanged,
    required this.onWakeTimeChanged,
    required this.onSleepTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          enabled ? 'MODO EDIÇÃO' : 'VISÃO GERAL',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: enabled ? palette.primary : palette.muted,
            letterSpacing: 0.12,
          ),
        ),
        const SizedBox(height: 14),
        FigmaFormFieldLabel(text: 'Nome'),
        const SizedBox(height: 8),
        FigmaFormTextField(
          controller: nameController,
          enabled: enabled,
        ),
        const SizedBox(height: 16),
        FigmaFormFieldLabel(text: 'Data de Nascimento'),
        const SizedBox(height: 8),
        FigmaFormTextField(
          controller: birthDateController,
          enabled: enabled,
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FigmaFormFieldLabel(text: 'Peso (KG)'),
                  const SizedBox(height: 8),
                  FigmaFormTextField(
                    controller: weightController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FigmaFormFieldLabel(text: 'Altura (CM)'),
                  const SizedBox(height: 8),
                  FigmaFormTextField(
                    controller: heightController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FigmaFormFieldLabel(text: 'Nível'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: levels
              .map(
                (level) => FigmaSelectionButton(
                  label: level.$2,
                  selected: selectedLevel == level.$1,
                  onTap: () => onLevelChanged(level.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        FigmaFormFieldLabel(text: 'Objetivo'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: goals
              .map(
                (goal) => FigmaSelectionButton(
                  label: goal,
                  selected: selectedGoal == goal,
                  onTap: () => onGoalChanged(goal),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        FigmaFormFieldLabel(text: 'Frequência'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: frequencyOptions
              .map(
                (option) => FigmaSelectionButton(
                  label: '${option}x',
                  selected: frequency == option,
                  onTap: () => onFrequencyChanged(option),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        FigmaFormFieldLabel(text: 'Gênero'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            ('male', 'Masculino'),
            ('female', 'Feminino'),
            ('other', 'Outro'),
            ('na', 'Prefiro não dizer'),
          ]
              .map(
                (g) => FigmaSelectionButton(
                  label: g.$2,
                  selected: gender == g.$1,
                  onTap: () => onGenderChanged(g.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        FigmaFormFieldLabel(text: 'Período preferido'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            ('manha', 'Manhã'),
            ('tarde', 'Tarde'),
            ('noite', 'Noite'),
          ]
              .map(
                (p) => FigmaSelectionButton(
                  label: p.$2,
                  selected: runPeriod == p.$1,
                  onTap: () => onRunPeriodChanged(p.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FigmaFormFieldLabel(text: 'Acordar'),
                  const SizedBox(height: 8),
                  _TimePickerField(
                    value: wakeTime,
                    enabled: enabled,
                    onChanged: onWakeTimeChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FigmaFormFieldLabel(text: 'Dormir'),
                  const SizedBox(height: 8),
                  _TimePickerField(
                    value: sleepTime,
                    enabled: enabled,
                    onChanged: onSleepTimeChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FigmaFormFieldLabel(text: 'FC Repouso'),
                  const SizedBox(height: 8),
                  FigmaFormTextField(
                    controller: restingBpmController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FigmaFormFieldLabel(text: 'FC Máxima'),
                  const SizedBox(height: 8),
                  FigmaFormTextField(
                    controller: maxBpmController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FigmaFormFieldLabel(text: 'Wearable'),
        const SizedBox(height: 8),
        _WearableConnectRow(
          hasWearable: hasWearable,
          onWearableChanged: onWearableChanged,
        ),
      ],
    );
  }
}

/// Status + atalho pra /profile/health/devices, que é onde mora o flow real
/// de conexão Apple Health / Health Connect (plugin `health`).
class _WearableConnectRow extends StatefulWidget {
  final bool hasWearable;
  final ValueChanged<bool> onWearableChanged;
  const _WearableConnectRow({
    required this.hasWearable,
    required this.onWearableChanged,
  });

  @override
  State<_WearableConnectRow> createState() => _WearableConnectRowState();
}

class _WearableConnectRowState extends State<_WearableConnectRow> {
  bool _checking = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!healthSyncService.isSupported) {
      if (mounted) setState(() { _checking = false; _connected = false; });
      return;
    }
    try {
      final ok = await healthSyncService.hasPermissions();
      if (mounted) setState(() { _checking = false; _connected = ok; });
      // Espelha estado real no perfil persistido (campo hasWearable).
      if (ok && !widget.hasWearable) widget.onWearableChanged(true);
    } catch (_) {
      if (mounted) setState(() { _checking = false; _connected = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final platformSupported = healthSyncService.isSupported;
    final statusText = !platformSupported
        ? 'Sincronização nativa só está disponível em iOS/Android.'
        : _checking
            ? 'Checando conexão…'
            : _connected
                ? 'Conectado · Apple Health / Health Connect ativo.'
                : 'Não conectado. Toque pra escolher um dispositivo.';
    return GestureDetector(
      onTap: () async {
        await context.push('/profile/health/devices');
        if (mounted) await _refresh();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(
              _connected ? Icons.check_circle_outline : Icons.watch_outlined,
              size: 20,
              color: _connected ? palette.primary : palette.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _connected ? 'DISPOSITIVO CONECTADO' : 'CONECTAR DISPOSITIVO',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(statusText, style: TextStyle(color: palette.muted, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _TimePickerField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final display = value ?? '--:--';

    return GestureDetector(
      onTap: enabled
          ? () async {
              final initial = _parseHHmm(value) ?? TimeOfDay.now();
              final picked = await showTimePicker(
                context: context,
                initialTime: initial,
              );
              if (picked != null) {
                final hh = picked.hour.toString().padLeft(2, '0');
                final mm = picked.minute.toString().padLeft(2, '0');
                onChanged('$hh:$mm');
              }
            }
          : null,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border, width: 1.0),
        ),
        child: Text(
          display,
          style: TextStyle(
            color: enabled ? palette.text : palette.muted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  static TimeOfDay? _parseHHmm(String? raw) {
    if (raw == null || !raw.contains(':')) return null;
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w500,
        color: palette.muted,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _StatCard({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      padding: const EdgeInsets.all(16),
      borderColor: accent
          ? palette.primary.withValues(alpha: 0.4)
          : palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: palette.muted,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: accent ? palette.primary : palette.text,
              letterSpacing: -0.02,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnonPromoBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AnonPromoBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.08),
          border: Border.all(color: palette.primary, width: 1.041),
        ),
        child: Row(
          children: [
            Icon(Icons.account_circle_outlined, color: context.runninPalette.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CRIE SUA CONTA',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: palette.primary, letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Você está como visitante. Conecte e-mail, telefone ou Google para não perder seus dados.',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, fontWeight: FontWeight.w400,
                      color: palette.text.withValues(alpha: 0.75),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: palette.text.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }
}

