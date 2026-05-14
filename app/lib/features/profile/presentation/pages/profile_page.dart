import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/theme_controller.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/user_profile_header.dart';

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

  List<Run>? _runs;
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String _level = 'iniciante';
  String _goal = 'Completar 10K';
  int _frequency = 4;
  bool _hasWearable = false;
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
    _level = profile?.level ?? 'iniciante';
    _goal = profile?.goal ?? 'Completar 10K';
    _frequency = profile?.frequency ?? 4;
    _hasWearable = profile?.hasWearable ?? false;
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
      _saveMessage = null;
      _error = null;
    });

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

  Future<void> _activateTrial() async {
    setState(() {
      _saving = true;
      _saveMessage = null;
      _error = null;
    });
    try {
      final updated = await _userDatasource.activateTrial();
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
        _saveMessage = 'Trial Pro de 7 dias ativado.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Não foi possível ativar o trial agora.';
      });
    }
  }

  void _redoOnboarding() {
    context.push('/onboarding?redo=1');
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

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'PERFIL',
              trailing: _loading
                  ? null
                  : TextButton(
                      onPressed: _editing
                          ? _cancelEdit
                          : () => setState(() => _editing = true),
                      child: Text(_editing ? 'CANCELAR' : 'EDITAR'),
                    ),
            ),
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
                          const SizedBox(height: 24),
                          _SectionLabel(label: 'PERFIL'),
                          const SizedBox(height: 8),
                          _ProfileEditor(
                            nameController: _nameCtrl,
                            birthDateController: _birthDateCtrl,
                            weightController: _weightCtrl,
                            heightController: _heightCtrl,
                            selectedLevel: _level,
                            selectedGoal: _goal,
                            frequency: _frequency,
                            hasWearable: _hasWearable,
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
                          const SizedBox(height: 32),
                          _SectionLabel(label: 'PLANO'),
                          const SizedBox(height: 8),
                          _PlanCard(
                            profile: _profile,
                            saving: _saving,
                            onActivateTrial: _activateTrial,
                            onRedoOnboarding: _redoOnboarding,
                          ),
                          const SizedBox(height: 32),
                          _SectionLabel(label: 'SKIN'),
                          const SizedBox(height: 8),
                          Text(
                            'Escolha a paleta principal inspirada no protótipo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedBuilder(
                            animation: themeController,
                            builder: (context, _) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SkinCard(
                                          skin: RunninSkin.sangue,
                                          isActive:
                                              themeController.skin ==
                                              RunninSkin.sangue,
                                          onTap: () => themeController.setSkin(
                                            RunninSkin.sangue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _SkinCard(
                                          skin: RunninSkin.magenta,
                                          isActive:
                                              themeController.skin ==
                                              RunninSkin.magenta,
                                          onTap: () => themeController.setSkin(
                                            RunninSkin.magenta,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SkinCard(
                                          skin: RunninSkin.volt,
                                          isActive:
                                              themeController.skin ==
                                              RunninSkin.volt,
                                          onTap: () => themeController.setSkin(
                                            RunninSkin.volt,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _SkinCard(
                                          skin: RunninSkin.artico,
                                          isActive:
                                              themeController.skin ==
                                              RunninSkin.artico,
                                          onTap: () => themeController.setSkin(
                                            RunninSkin.artico,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          _SectionLabel(label: 'CONTA'),
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
                                      fontWeight: FontWeight.w700,
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

class _ProfileHero extends StatelessWidget {
  final User? firebaseUser;
  final UserProfile? profile;
  final bool isAnonymous;
  final int levelNumber;
  final int totalRuns;
  final double totalDistanceKm;

  const _ProfileHero({
    required this.firebaseUser,
    required this.profile,
    required this.isAnonymous,
    required this.levelNumber,
    required this.totalRuns,
    required this.totalDistanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : (firebaseUser?.displayName ?? 'Corredor');
    final goal = profile?.goal.isNotEmpty == true
        ? profile!.goal
        : 'Meta em definição';
    final level = profile?.level ?? 'iniciante';
    final statusLabel = isAnonymous ? 'MODO ANONIMO' : 'CONTA CONECTADA';

    return AppPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (firebaseUser?.photoURL != null)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.border),
                    image: DecorationImage(
                      image: NetworkImage(firebaseUser!.photoURL!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  color: palette.primary,
                  child: Text(
                    name.isNotEmpty ? name.characters.first.toUpperCase() : 'R',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: palette.background,
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nível $levelNumber · ${_formatRunnerLevel(level)}',
                      style: TextStyle(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isAnonymous ? palette.secondary : palette.primary,
              letterSpacing: 0.12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goal,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.text.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalRuns corridas · ${totalDistanceKm.toStringAsFixed(1)}km total',
            style: TextStyle(color: palette.muted),
          ),
          if (isAnonymous) ...[
            const SizedBox(height: 6),
            Text(
              'Conecte sua conta em Acesso da conta para salvar tudo na nuvem.',
              style: TextStyle(color: palette.secondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRunnerLevel(String level) {
    switch (level) {
      case 'intermediario':
        return 'Intermediário';
      case 'avancado':
        return 'Avançado';
      default:
        return 'Iniciante';
    }
  }
}

class _ProfileEditor extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController birthDateController;
  final TextEditingController weightController;
  final TextEditingController heightController;
  final String selectedLevel;
  final String selectedGoal;
  final int frequency;
  final bool hasWearable;
  final List<(String, String)> levels;
  final List<String> goals;
  final List<int> frequencyOptions;
  final bool enabled;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onGoalChanged;
  final ValueChanged<int> onFrequencyChanged;
  final ValueChanged<bool> onWearableChanged;

  const _ProfileEditor({
    required this.nameController,
    required this.birthDateController,
    required this.weightController,
    required this.heightController,
    required this.selectedLevel,
    required this.selectedGoal,
    required this.frequency,
    required this.hasWearable,
    required this.levels,
    required this.goals,
    required this.frequencyOptions,
    required this.enabled,
    required this.onLevelChanged,
    required this.onGoalChanged,
    required this.onFrequencyChanged,
    required this.onWearableChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enabled ? 'MODO EDIÇÃO' : 'VISÃO GERAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: enabled ? palette.primary : palette.muted,
              letterSpacing: 0.12,
            ),
          ),
          const SizedBox(height: 14),
          _FieldLabel(label: 'NOME'),
          const SizedBox(height: 8),
          _ProfileTextField(controller: nameController, enabled: enabled),
          const SizedBox(height: 16),
          _FieldLabel(label: 'DATA DE NASCIMENTO'),
          const SizedBox(height: 8),
          _ProfileTextField(
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
                    _FieldLabel(label: 'PESO (KG)'),
                    const SizedBox(height: 8),
                    _ProfileTextField(
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
                    _FieldLabel(label: 'ALTURA (CM)'),
                    const SizedBox(height: 8),
                    _ProfileTextField(
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
          _FieldLabel(label: 'NÍVEL'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: levels
                .map(
                  (level) => _SelectChip(
                    label: level.$2,
                    selected: selectedLevel == level.$1,
                    enabled: enabled,
                    onTap: () => onLevelChanged(level.$1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _FieldLabel(label: 'OBJETIVO'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: goals
                .map(
                  (goal) => _SelectChip(
                    label: goal,
                    selected: selectedGoal == goal,
                    enabled: enabled,
                    onTap: () => onGoalChanged(goal),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _FieldLabel(label: 'FREQUÊNCIA'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: frequencyOptions
                .map(
                  (option) => _SelectChip(
                    label: '${option}x',
                    selected: frequency == option,
                    enabled: enabled,
                    onTap: () => onFrequencyChanged(option),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _FieldLabel(label: 'WEARABLE'),
          const SizedBox(height: 8),
          SwitchListTile(
            value: hasWearable,
            onChanged: enabled ? onWearableChanged : null,
            activeThumbColor: palette.primary,
            activeTrackColor: palette.primary.withValues(alpha: 0.35),
            contentPadding: EdgeInsets.zero,
            title: Text(
              hasWearable ? 'Tenho/pretendo conectar' : 'Depois',
              style: TextStyle(color: palette.text),
            ),
            subtitle: Text(
              'Isso ainda nao confirma dados conectados. Health Connect / HealthKit sera usado na proxima fase.',
              style: TextStyle(color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;

  const _ProfileTextField({
    required this.controller,
    required this.enabled,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(color: palette.text),
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled ? palette.surface : palette.surfaceAlt,
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return GestureDetector(
      onTap: enabled ? onTap : null,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.primary : palette.muted,
          ),
        ),
      ),
    );
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
        fontWeight: FontWeight.w700,
        color: palette.muted,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
              color: palette.muted,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: accent ? palette.primary : palette.text,
              letterSpacing: -0.02,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final RunninSkin skin;
  final bool isActive;
  final VoidCallback onTap;

  const _SkinCard({
    required this.skin,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = skin.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(
            color: isActive ? palette.primary : palette.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: palette.previewBars
                  .map(
                    (color) => Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 6),
                      color: color,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                skin.palette.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.08,
                  color: palette.text,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Container(height: 4, color: palette.primary)),
                Expanded(child: Container(height: 4, color: palette.secondary)),
                Expanded(child: Container(height: 4, color: palette.tertiary)),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'ATIVA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.12,
                    color: palette.primary,
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

class _PlanCard extends StatelessWidget {
  final UserProfile? profile;
  final bool saving;
  final VoidCallback onActivateTrial;
  final VoidCallback onRedoOnboarding;

  const _PlanCard({
    required this.profile,
    required this.saving,
    required this.onActivateTrial,
    required this.onRedoOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final isPro = profile?.isPro ?? false;
    return AppPanel(
      color: isPro
          ? palette.primary.withValues(alpha: 0.06)
          : palette.surfaceAlt,
      borderColor: isPro
          ? palette.primary.withValues(alpha: 0.45)
          : palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPro ? Icons.workspace_premium_outlined : Icons.lock_outline,
                size: 16,
                color: isPro ? palette.primary : palette.muted,
              ),
              const SizedBox(width: 8),
              Text(
                isPro ? 'PLANO PRO' : 'PLANO FREE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.12,
                  color: isPro ? palette.primary : palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isPro) ..._buildProBody(context, palette) else ..._buildFreeBody(context, palette),
        ],
      ),
    );
  }

  List<Widget> _buildProBody(BuildContext context, RunninPalette palette) {
    final until = profile?.premiumUntil;
    final untilLabel = until == null
        ? '—'
        : '${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}';
    final remaining = until?.difference(DateTime.now());
    final remainingLabel = remaining == null
        ? null
        : remaining.inDays > 0
            ? '${remaining.inDays} dia(s) restantes'
            : remaining.inHours > 0
                ? '${remaining.inHours} hora(s) restantes'
                : 'Expira em breve';

    return [
      Text(
        'Coach AI completo, plano vivo e refazer onboarding semanal.',
        style: TextStyle(color: palette.text, height: 1.5, fontSize: 13),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Text(
            'Válido até $untilLabel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
          if (remainingLabel != null) ...[
            const SizedBox(width: 8),
            Text(
              '· $remainingLabel',
              style: TextStyle(fontSize: 11, color: palette.muted),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _RedoOnboardingRow(
        profile: profile,
        saving: saving,
        onTap: onRedoOnboarding,
      ),
    ];
  }

  List<Widget> _buildFreeBody(BuildContext context, RunninPalette palette) {
    return [
      Text(
        'Você está no plano gratuito. Pode usar o app normalmente, mas o Coach AI fica reservado para o plano Pro.',
        style: TextStyle(color: palette.text, height: 1.5, fontSize: 13),
      ),
      const SizedBox(height: 12),
      _PlanBenefitRow(text: 'Coach AI por voz e em chat', palette: palette),
      _PlanBenefitRow(text: 'Plano que se ajusta a cada corrida', palette: palette),
      _PlanBenefitRow(text: 'Refazer onboarding 1× por semana', palette: palette),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: saving ? null : onActivateTrial,
          child: saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.background,
                  ),
                )
              : const Text('ATIVAR TRIAL 7 DIAS'),
        ),
      ),
    ];
  }
}

class _PlanBenefitRow extends StatelessWidget {
  final String text;
  final RunninPalette palette;
  const _PlanBenefitRow({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.check, size: 12, color: palette.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: palette.text, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedoOnboardingRow extends StatelessWidget {
  final UserProfile? profile;
  final bool saving;
  final VoidCallback onTap;
  const _RedoOnboardingRow({
    required this.profile,
    required this.saving,
    required this.onTap,
  });

  static const _cooldownDays = 7;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final last = profile?.lastOnboardingAt;
    final next = last?.add(const Duration(days: _cooldownDays));
    final canRedo = next == null || next.isBefore(DateTime.now());
    final daysLeft = next == null
        ? 0
        : next.difference(DateTime.now()).inDays + 1;

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: (saving || !canRedo) ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: canRedo ? palette.primary : palette.border,
          ),
          foregroundColor: canRedo ? palette.primary : palette.muted,
        ),
        child: Text(
          canRedo
              ? 'REFAZER ONBOARDING'
              : 'REFAZER EM $daysLeft DIA${daysLeft == 1 ? '' : 'S'}',
        ),
      ),
    );
  }
}
