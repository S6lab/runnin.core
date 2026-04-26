import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _signingOut = false;
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

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;
    final profileName = _profile?.name.trim();
    final displayName = user?.displayName?.trim();
    final title = (profileName != null && profileName.isNotEmpty)
        ? profileName
        : (displayName != null && displayName.isNotEmpty)
        ? displayName
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
            const AppPageHeader(title: 'CONTA'),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
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
                                  Text(
                                    title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: palette.muted,
                                      fontSize: 12,
                                    ),
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
                            fontSize: 11,
                            color: isAnonymous
                                ? palette.secondary
                                : palette.primary,
                            letterSpacing: 0.12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          statusMessage,
                          style: TextStyle(
                            color: palette.text.withValues(alpha: 0.82),
                            height: 1.5,
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
                  _AccountSectionLabel(label: 'PESSOAL'),
                  _AccountActionTile(
                    icon: Icons.edit_outlined,
                    title: 'Editar perfil',
                    subtitle: 'Ajuste dados pessoais, meta e frequência.',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  const SizedBox(height: 10),
                  _AccountActionTile(
                    icon: Icons.lock_outline,
                    title: isAnonymous ? 'Proteger conta' : 'Acesso da conta',
                    subtitle: isAnonymous
                        ? 'Vincule e-mail e senha sem perder seus dados.'
                        : 'Gerencie formas de acesso, e-mail e telefone.',
                    onTap: () => context.push('/profile/access'),
                  ),
                  const SizedBox(height: 10),
                  _AccountSectionLabel(label: 'JORNADA'),
                  _AccountActionTile(
                    icon: Icons.fact_check_outlined,
                    title: 'Refazer onboarding',
                    subtitle:
                        'Revisite o setup inicial e atualize suas preferências.',
                    onTap: () {
                      markOnboardingPending();
                      context.go('/onboarding');
                    },
                  ),
                  const SizedBox(height: 10),
                  _AccountActionTile(
                    icon: Icons.bar_chart_outlined,
                    title: 'Analytics',
                    subtitle: 'Veja volume, pace, streak e evolução.',
                    onTap: () => context.push('/dashboard'),
                  ),
                  const SizedBox(height: 24),
                  _AccountSectionLabel(label: 'SESSÃO'),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _signingOut ? null : _signOut,
                      child: _signingOut
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.primary,
                              ),
                            )
                          : const Text('SAIR'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSectionLabel extends StatelessWidget {
  final String label;

  const _AccountSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: palette.muted,
          letterSpacing: 0.12,
        ),
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AccountActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

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
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
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
