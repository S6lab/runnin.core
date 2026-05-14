import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/theme_controller.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/palette_card.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _signingOut = false;
  bool _savingVoice = false;
  final _userDs = UserRemoteDatasource();
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _userDs.getMe();
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (_) {}
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _showLogoutConfirmation() async {
    final palette = context.runninPalette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Sair da conta?', style: TextStyle(color: palette.text)),
        content: Text(
          'Você será desconectado e redirecionado para a tela de login.',
          style: TextStyle(color: palette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('SAIR', style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _signOut();
  }

  Future<void> _selectCoachVoice(String voiceId) async {
    if (_savingVoice || _profile?.coachVoiceId == voiceId) return;
    setState(() => _savingVoice = true);
    try {
      final updated = await _userDs.patchMe(coachVoiceId: voiceId);
      if (!mounted) return;
      setState(() => _profile = updated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel salvar a voz do coach.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingVoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;
    final profileName = _profile?.name.trim();
    final displayName = user?.displayName?.trim();
    final title = (profileName?.isNotEmpty == true)
        ? profileName!
        : (displayName?.isNotEmpty == true)
        ? displayName!
        : (isAnonymous ? 'Modo anônimo' : 'Minha conta');
    final subtitle =
        user?.email ??
        (isAnonymous ? 'Sessão local ativa' : 'Sem e-mail conectado');
    final statusLabel = isAnonymous ? 'MODO ANONIMO ATIVO' : 'CONTA PROTEGIDA';
    final statusMessage = isAnonymous
        ? 'Seu perfil ($title) esta salvo localmente neste dispositivo. Conecte uma conta para manter historico e plano sincronizados na nuvem.'
        : 'Seu acesso já está vinculado. Você pode editar perfil, revisar onboarding e gerenciar métodos de login.';

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: 'PERFIL'),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // ── Identidade ────────────────────────────────────────────
                  AppPanel(
                    color: palette.surfaceAlt,
                    borderColor: palette.primary.withValues(alpha: 0.35),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: palette.surface,
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: user?.photoURL == null
                                  ? Text(
                                      title[0].toUpperCase(),
                                      style: TextStyle(
                                        color: palette.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: type.displaySm),
                                  const SizedBox(height: 4),
                                  Text(subtitle, style: type.bodySm),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          statusLabel,
                          style: type.labelCaps.copyWith(
                            color: isAnonymous
                                ? palette.secondary
                                : palette.primary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          statusMessage,
                          style: type.bodyMd.copyWith(
                            color: palette.text.withValues(alpha: 0.82),
                          ),
                        ),
                        if (isAnonymous) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => context.push('/profile/access'),
                              child: const Text('CONECTAR CONTA PARA NUVEM'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Visual / Skin ─────────────────────────────────────────
                  _SectionLabel(label: 'VISUAL'),
                  _SkinSwitcher(),
                  const SizedBox(height: 16),

                  _SectionLabel(label: 'VOZ DO COACH'),
                  _CoachVoicePicker(
                    selectedVoiceId: _profile?.coachVoiceId ?? 'coach-bruno',
                    saving: _savingVoice,
                    onSelected: _selectCoachVoice,
                  ),
                  const SizedBox(height: 16),

                  // ── Pessoal ───────────────────────────────────────────────
                  _SectionLabel(label: 'PESSOAL'),
                  _ActionTile(
                    icon: Icons.edit_outlined,
                    title: 'Editar perfil',
                    subtitle: 'Ajuste dados pessoais, meta e frequência.',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.lock_outline,
                    title: isAnonymous ? 'Proteger conta' : 'Acesso da conta',
                    subtitle: isAnonymous
                        ? 'Vincule e-mail e senha sem perder seus dados.'
                        : 'Gerencie formas de acesso, e-mail e telefone.',
                    onTap: () => context.push('/profile/access'),
                  ),
                  const SizedBox(height: 16),

                  // ── Jornada ───────────────────────────────────────────────
                  _SectionLabel(label: 'JORNADA'),
                  _ActionTile(
                    icon: Icons.emoji_events_outlined,
                    title: 'Gamificação',
                    subtitle: 'Badges, XP, streak e conquistas.',
                    onTap: () => context.push('/gamification'),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.bar_chart_outlined,
                    title: 'Analytics',
                    subtitle: 'Veja volume, pace, streak e evolução.',
                    onTap: () => context.push('/dashboard'),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.fact_check_outlined,
                    title: 'Refazer onboarding',
                    subtitle:
                        'Revisite o setup inicial e atualize suas preferências.',
                    onTap: () {
                      markOnboardingPending();
                      context.go('/onboarding');
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Ações ─────────────────────────────────────────────────
                  _ProfileActionButtons(
                    signingOut: _signingOut,
                    onEditProfile: () => context.push('/profile/edit'),
                    onLogout: _showLogoutConfirmation,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skin Switcher ─────────────────────────────────────────────────────────────

class _SkinSwitcher extends StatefulWidget {
  @override
  State<_SkinSwitcher> createState() => _SkinSwitcherState();
}

class _SkinSwitcherState extends State<_SkinSwitcher> {
  RunninSkin _selected = themeController.skin;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      children: RunninSkin.values
          .map(
            (skin) => PaletteCard(
              skin: skin,
              isSelected: _selected == skin,
              onTap: () {
                setState(() => _selected = skin);
                themeController.setSkin(skin);
              },
            ),
          )
          .toList(),
    );
  }
}

class _CoachVoicePicker extends StatelessWidget {
  final String selectedVoiceId;
  final bool saving;
  final ValueChanged<String> onSelected;

  const _CoachVoicePicker({
    required this.selectedVoiceId,
    required this.saving,
    required this.onSelected,
  });

  static const _voices = [
    _CoachVoiceOption(
      id: 'coach-bruno',
      name: 'Bruno',
      tone: 'Firme e direto',
      description: 'Voz masculina Neural2 para comandos objetivos.',
    ),
    _CoachVoiceOption(
      id: 'coach-clara',
      name: 'Clara',
      tone: 'Calma e precisa',
      description: 'Voz feminina Neural2 para orientação controlada.',
    ),
    _CoachVoiceOption(
      id: 'coach-luna',
      name: 'Luna',
      tone: 'Leve e motivadora',
      description: 'Voz feminina Neural2 com energia de treino.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
      child: Column(
        children: [
          ..._voices.map((voice) {
            final selected = selectedVoiceId == voice.id;
            return InkWell(
              onTap: saving ? null : () => onSelected(voice.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected ? palette.primary : palette.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(voice.name, style: context.runninType.labelMd),
                          const SizedBox(height: 3),
                          Text(
                            '${voice.tone} · ${voice.description}',
                            style: context.runninType.bodySm.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (saving && selected)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: palette.primary,
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CoachVoiceOption {
  final String id;
  final String name;
  final String tone;
  final String description;

  const _CoachVoiceOption({
    required this.id,
    required this.name,
    required this.tone,
    required this.description,
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label, style: context.runninType.labelCaps),
    );
  }
}

class _ProfileActionButtons extends StatelessWidget {
  final bool signingOut;
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;

  const _ProfileActionButtons({
    required this.signingOut,
    required this.onEditProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Editar perfil button
          SizedBox(
            height: 47,
            width: double.infinity,
            child: Material(
              color: Colors.white.withValues(alpha: 0.03),
              child: InkWell(
                onTap: onEditProfile,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.735,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: palette.text.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Editar perfil ↗',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: palette.text.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Logout button
          SizedBox(
            height: 43,
            width: double.infinity,
            child: GestureDetector(
              onTap: signingOut ? null : onLogout,
              child: Center(
                child: signingOut
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.text.withValues(alpha: 0.2),
                        ),
                      )
                    : Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: palette.text.withValues(alpha: 0.2),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return AppPanel(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: palette.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: type.labelMd),
                  const SizedBox(height: 4),
                  Text(subtitle, style: type.bodySm),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.muted),
          ],
        ),
      ),
    );
  }
}
