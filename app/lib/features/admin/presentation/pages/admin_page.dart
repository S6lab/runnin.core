import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/admin/data/admin_cron_datasource.dart';
import 'package:runnin/features/admin/data/admin_registry_datasource.dart';
import 'package:runnin/features/admin/data/admin_users_datasource.dart';
import 'package:runnin/features/admin/domain/registry_entries.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _auth = FirebaseAuth.instance;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late final StreamSubscription<User?> _authSub;
  User? _user;
  AdminSession? _session;
  bool _loadingSession = true;
  bool _signingIn = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _authSub = _auth.authStateChanges().listen((user) {
      _user = user;
      unawaited(_loadSession());
    });
    unawaited(_loadSession());
  }

  @override
  void dispose() {
    _authSub.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    setState(() {
      _loadingSession = true;
      _error = null;
      _message = null;
    });

    try {
      if (user == null || user.isAnonymous) {
        setState(() => _session = null);
        return;
      }

      final token = await user.getIdTokenResult(forceRefresh);
      final session = AdminSession.fromClaims(user, token.claims ?? {});
      setState(() => _session = session);
    } catch (_) {
      setState(() => _error = 'Nao foi possivel validar sua permissao.');
    } finally {
      if (mounted) setState(() => _loadingSession = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.length < 6) {
      setState(
        () => _error = 'Informe e-mail e senha com pelo menos 6 caracteres.',
      );
      return;
    }

    setState(() {
      _signingIn = true;
      _error = null;
      _message = null;
    });

    try {
      if (_auth.currentUser?.isAnonymous == true) {
        await _auth.signOut();
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _loadSession(forceRefresh: true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (_) {
      setState(() => _error = 'Nao foi possivel entrar agora.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _signingIn = true;
      _error = null;
      _message = null;
    });

    try {
      if (_auth.currentUser?.isAnonymous == true) {
        await _auth.signOut();
      }

      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        setState(() {
          _error = 'Login Google do admin esta disponivel no web app.';
        });
        return;
      }

      await _loadSession(forceRefresh: true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (_) {
      setState(() => _error = 'Nao foi possivel entrar com Google agora.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    setState(() {
      _session = null;
      _message = null;
      _error = null;
    });
  }


  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'O e-mail informado nao e valido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha invalidos.';
      case 'popup-closed-by-user':
        return 'Login cancelado.';
      case 'operation-not-allowed':
        return 'Habilite este metodo de login no Firebase Auth.';
      default:
        return 'Nao foi possivel autenticar este usuario.';
    }
  }


  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final session = _session;
    final needsLogin = _user == null || _user?.isAnonymous == true;
    final blocked = !needsLogin && session != null && !session.canRead;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdminHeader(
                    session: session,
                    loading: _loadingSession,
                    onRefreshClaims: () => _loadSession(forceRefresh: true),
                    onSignOut: _signOut,
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    _Notice(text: _error!, tone: _NoticeTone.error),
                  if (_message != null)
                    _Notice(text: _message!, tone: _NoticeTone.success),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: needsLogin
                          ? _LoginPanel(
                              key: const ValueKey('login'),
                              emailCtrl: _emailCtrl,
                              passwordCtrl: _passwordCtrl,
                              loading: _signingIn,
                              onEmailLogin: _signInWithEmail,
                              onGoogleLogin: _signInWithGoogle,
                            )
                          : _loadingSession && session == null
                          ? const Center(child: CircularProgressIndicator())
                          : blocked
                          ? _BlockedPanel(
                              key: const ValueKey('blocked'),
                              email: _user?.email,
                              onSignOut: _signOut,
                              onRefresh: () => _loadSession(forceRefresh: true),
                            )
                          : _DrivePanel(
                              key: const ValueKey('drive'),
                              session: session!,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminSession {
  final String uid;
  final String? email;
  final String role;
  final bool canRead;
  final bool canUpload;
  final bool canDelete;

  const AdminSession({
    required this.uid,
    required this.email,
    required this.role,
    required this.canRead,
    required this.canUpload,
    required this.canDelete,
  });

  factory AdminSession.fromClaims(User user, Map<String, dynamic> claims) {
    final rawRole = claims['role'] ?? claims['adminRole'];
    final roles = claims['roles'];
    final hasAdminFlag = claims['admin'] == true;
    final role = rawRole is String
        ? rawRole
        : hasAdminFlag
        ? 'admin'
        : roles is Iterable && roles.contains('editor')
        ? 'editor'
        : roles is Iterable && roles.contains('admin')
        ? 'admin'
        : 'none';

    final normalized = role.toLowerCase();
    final isAdmin = hasAdminFlag || normalized == 'admin';
    final isEditor = normalized == 'editor';

    return AdminSession(
      uid: user.uid,
      email: user.email,
      role: isAdmin
          ? 'admin'
          : isEditor
          ? 'editor'
          : normalized,
      canRead: isAdmin || isEditor,
      canUpload: isAdmin || isEditor,
      canDelete: isAdmin,
    );
  }
}

class _AdminHeader extends StatelessWidget {
  final AdminSession? session;
  final bool loading;
  final VoidCallback onRefreshClaims;
  final VoidCallback onSignOut;

  const _AdminHeader({
    required this.session,
    required this.loading,
    required this.onRefreshClaims,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RUNNIN ADMIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Arquivos de conhecimento para RAG',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        if (session != null) ...[
          _RolePill(role: session!.role),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Atualizar permissoes',
            onPressed: loading ? null : onRefreshClaims,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool loading;
  final VoidCallback onEmailLogin;
  final VoidCallback onGoogleLogin;

  const _LoginPanel({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.onEmailLogin,
    required this.onGoogleLogin,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Acesso administrativo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-mail'),
                onSubmitted: (_) => onEmailLogin(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Senha'),
                onSubmitted: (_) => onEmailLogin(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : onEmailLogin,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open),
                  label: const Text('ENTRAR'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onGoogleLogin,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('GOOGLE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedPanel extends StatelessWidget {
  final String? email;
  final VoidCallback onSignOut;
  final VoidCallback onRefresh;

  const _BlockedPanel({
    super.key,
    required this.email,
    required this.onSignOut,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 44),
              const SizedBox(height: 14),
              Text(
                'Sem permissao para o painel',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                email ?? 'Usuario autenticado',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.sync),
                    label: const Text('ATUALIZAR'),
                  ),
                  TextButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('SAIR'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrivePanel extends StatelessWidget {
  final AdminSession session;

  const _DrivePanel({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          _TechMetricsEntry(canRead: session.canRead),
          const SizedBox(height: 8),
          _CoachAiConsoleEntry(canRead: session.canRead),
          const SizedBox(height: 8),
          _PromptsConsoleEntry(canRead: session.canRead),
          const SizedBox(height: 8),
          _CoachRuntimeEntry(canRead: session.canRead),
          const SizedBox(height: 8),
          _TokensEntry(canRead: session.canRead),
          const SizedBox(height: 8),
          _PlanRulesEntry(canRead: session.canRead),
          const SizedBox(height: 8),
          _CronTriggersPanel(canTrigger: session.canUpload),
          const SizedBox(height: 14),
          _UsersPanel(canEdit: session.canUpload),
        ],
      ),
    );
  }
}

// ───────────────────────────── Cron triggers (manual) ─────────────────────

/// Disparo manual de jobs do Cloud Scheduler — usado pra simular o
/// comportamento de cron sem ter que esperar a janela real. Lista vem de
/// `GET /admin/crons` (espelha `infra/scheduler.tf`). Botão DISPARAR
/// aparece só pro weekly-plan-proposals (único trigger admin manual).
/// Auth: admin claim.
class _CronTriggersPanel extends StatefulWidget {
  final bool canTrigger;
  const _CronTriggersPanel({required this.canTrigger});

  @override
  State<_CronTriggersPanel> createState() => _CronTriggersPanelState();
}

class _CronTriggersPanelState extends State<_CronTriggersPanel> {
  final _ds = AdminCronDatasource();
  final _registry = AdminRegistryDatasource();
  List<CronEntry>? _crons;
  bool _running = false;
  String? _lastResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCrons();
  }

  Future<void> _loadCrons() async {
    try {
      final list = await _registry.listCrons();
      if (!mounted) return;
      setState(() => _crons = list);
    } catch (_) {
      // best-effort — se falha, segue com fallback de display estático
    }
  }

  Future<void> _triggerWeekly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disparar revisão semanal?'),
        content: const Text(
          'Simula o cron de domingo 06:00 BRT. Vai percorrer todos os '
          'usuários com plano ativo e enfileirar 1 task por user pra gerar '
          'a proposta de revisão das próximas 2 semanas. Idempotente — não '
          'duplica proposta pendente, mas pode gerar carga de LLM. Rodar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DISPARAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _running = true;
      _error = null;
      _lastResult = null;
    });
    try {
      final result = await _ds.triggerWeeklyProposals();
      if (!mounted) return;
      setState(() => _lastResult = result.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revisão semanal disparada · $result')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final disabled = !widget.canTrigger || _running;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'TRIGGERS DE CRON',
                style: context.runninType.labelMd.copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Dispara manualmente jobs do Cloud Scheduler pra simular execução fora da janela.',
            style: context.runninType.bodyXs.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 12),
          // Lista crons dinâmica do server (espelha infra/scheduler.tf).
          // Botão DISPARAR aparece só pro weekly-proposals (único trigger
          // manual exposto via auth-admin).
          if (_crons == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary),
              ),
            )
          else if (_crons!.isEmpty)
            Text(
              'Nenhum cron registrado.',
              style: context.runninType.bodyXs.copyWith(color: palette.muted),
            )
          else
            ..._crons!.map((cron) {
              final isWeekly = cron.name.startsWith('weekly-plan-proposals');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cron.description} · ${cron.humanSchedule} · ${cron.env}',
                            style: context.runninType.bodySm,
                          ),
                          Text(
                            '${cron.name} (cron: ${cron.schedule})',
                            style: context.runninType.bodyXs.copyWith(
                              color: palette.muted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isWeekly && cron.env == 'staging') ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: disabled ? null : _triggerWeekly,
                        child: _running
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('DISPARAR'),
                      ),
                    ],
                  ],
                ),
              );
            }),
          if (!widget.canTrigger) ...[
            const SizedBox(height: 8),
            Text(
              'Sem permissão pra disparar (precisa de admin write).',
              style: context.runninType.bodyXs.copyWith(color: palette.muted),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: context.runninType.bodyXs.copyWith(color: palette.error),
            ),
          ],
          if (_lastResult != null) ...[
            const SizedBox(height: 8),
            Text(
              'Último resultado: $_lastResult',
              style: context.runninType.bodyXs.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Users plan management ──────────────────────

class _UsersPanel extends StatefulWidget {
  final bool canEdit;
  const _UsersPanel({required this.canEdit});

  @override
  State<_UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends State<_UsersPanel> {
  final _ds = AdminUsersDatasource();
  final _registry = AdminRegistryDatasource();
  final _searchCtrl = TextEditingController();
  List<AdminUserSummary> _users = [];
  List<SubscriptionPlanOption> _plansCatalog = const [];
  bool _loading = false;
  String? _error;
  String? _savingUserId;

  @override
  void initState() {
    super.initState();
    _loadPlansCatalog();
  }

  Future<void> _loadPlansCatalog() async {
    try {
      final list = await _registry.listPlansCatalog();
      if (!mounted) return;
      setState(() => _plansCatalog = list);
    } catch (_) {
      // fallback hardcoded fica no DropdownMenu
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _ds.list(search: _searchCtrl.text.trim());
      if (mounted) setState(() => _users = r);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset(AdminUserSummary u, String mode) async {
    final isFull = mode == 'full';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFull ? 'Reset FULL de ${u.email ?? u.id}?' : 'Reset plano de ${u.email ?? u.id}?'),
        content: Text(
          isFull
              ? 'Apaga TUDO: planos, corridas, biométricos, mensagens do coach, exames OCR, devices. Revoga sessões. Histórico fica vazio. Irreversível.'
              : 'Apaga apenas o plano atual + reseta onboarded=false. Histórico de corridas e dados preservados. Revoga sessões (precisa re-logar). User passa onboarding novamente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isFull ? 'RESETAR FULL' : 'RESETAR PLANO'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() { _savingUserId = u.id; _error = null; });
    try {
      final result = await _ds.reset(userId: u.id, mode: mode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset $mode OK · ${result['deletedCounts']}')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _savingUserId = null);
    }
  }

  Future<void> _setPlan(AdminUserSummary u, String plan) async {
    setState(() => _savingUserId = u.id);
    try {
      await _ds.setPlan(userId: u.id, plan: plan);
      if (mounted) {
        setState(() {
          _users = _users
              .map((x) => x.id == u.id
                  ? AdminUserSummary(
                      id: x.id,
                      email: x.email,
                      name: x.name,
                      subscriptionPlanId: plan,
                      onboarded: x.onboarded,
                    )
                  : x)
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plano de ${u.email ?? u.id} alterado para $plan')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _savingUserId = null);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('USUÁRIOS — PLANO',
                  style: TextStyle(
                      color: palette.text, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1)),
              const Spacer(),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: palette.text, fontSize: 12),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'buscar (email / nome / uid)',
                    hintStyle: TextStyle(color: palette.muted, fontSize: 11),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: palette.border)),
                  ),
                  onSubmitted: (_) => _refresh(),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _loading ? null : _refresh,
                child: Text(_loading ? '…' : 'BUSCAR',
                    style: TextStyle(color: palette.primary, fontSize: 11, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: TextStyle(color: palette.error, fontSize: 11)),
            ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _users.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _loading ? 'carregando…' : 'use o buscar pra listar',
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _users.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: palette.border, height: 1),
                    itemBuilder: (_, i) {
                      final u = _users[i];
                      final saving = _savingUserId == u.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.email ?? u.id,
                                      style: TextStyle(
                                          color: palette.text, fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text(u.name ?? u.id,
                                      style: TextStyle(color: palette.muted, fontSize: 10)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (saving)
                              SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.primary),
                              )
                            else
                              Builder(builder: (_) {
                                // Lista do server (registry). Fallback estático
                                // se catálogo não carregou ainda.
                                final catalog = _plansCatalog.isNotEmpty
                                    ? _plansCatalog
                                    : const <SubscriptionPlanOption>[
                                        SubscriptionPlanOption(id: 'freemium', label: 'freemium', isDefault: true),
                                        SubscriptionPlanOption(id: 'pro_s6lab', label: 'pro · s6lab'),
                                        SubscriptionPlanOption(id: 'claro_basic', label: 'claro · básico'),
                                      ];
                                final validIds = catalog.map((p) => p.id).toSet();
                                final defaultId = catalog.firstWhere(
                                  (p) => p.isDefault,
                                  orElse: () => catalog.first,
                                ).id;
                                final value = validIds.contains(u.subscriptionPlanId)
                                    ? u.subscriptionPlanId
                                    : defaultId;
                                return DropdownButton<String>(
                                  value: value,
                                  items: [
                                    for (final p in catalog)
                                      DropdownMenuItem(value: p.id, child: Text(p.label)),
                                  ],
                                  onChanged: widget.canEdit
                                      ? (v) {
                                          if (v != null && v != u.subscriptionPlanId) _setPlan(u, v);
                                        }
                                      : null,
                                  style: TextStyle(color: palette.text, fontSize: 12),
                                  dropdownColor: palette.surface,
                                );
                              }),
                            const SizedBox(width: 6),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 18, color: palette.muted),
                              tooltip: 'Reset user',
                              color: palette.surface,
                              enabled: widget.canEdit && !saving,
                              onSelected: (mode) => _confirmReset(u, mode),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'plan',
                                  child: Text('Reset plano (manter histórico)',
                                      style: TextStyle(color: palette.text, fontSize: 12)),
                                ),
                                PopupMenuItem(
                                  value: 'full',
                                  child: Text('Reset FULL (zerar tudo)',
                                      style: TextStyle(color: palette.error, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Prompts console entry ──────────────────────

// ───────────────────────────── RAG status + reindex ──────────────────────

enum _NoticeTone { error, success }

class _Notice extends StatelessWidget {
  final String text;
  final _NoticeTone tone;

  const _Notice({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final color = tone == _NoticeTone.error ? palette.error : palette.success;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _CoachAiConsoleEntry extends StatelessWidget {
  final bool canRead;
  const _CoachAiConsoleEntry({required this.canRead});

  @override
  Widget build(BuildContext context) {
    if (!canRead) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: ListTile(
        leading: const Icon(Icons.hub_outlined),
        title: const Text('Console Coach.AI'),
        subtitle: const Text('5 momentos · 4 modelos · base de conhecimento (RAG) com purga'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/admin/coach-ai'),
      ),
    );
  }
}

class _PromptsConsoleEntry extends StatelessWidget {
  final bool canRead;
  const _PromptsConsoleEntry({required this.canRead});

  @override
  Widget build(BuildContext context) {
    if (!canRead) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: ListTile(
        leading: const Icon(Icons.tune),
        title: const Text('Prompts & Personas'),
        subtitle: const Text('Editar prompts dos momentos LLM, personas do coach, knobs do decision layer'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/admin/prompts'),
      ),
    );
  }
}

class _PlanRulesEntry extends StatelessWidget {
  final bool canRead;
  const _PlanRulesEntry({required this.canRead});

  @override
  Widget build(BuildContext context) {
    if (!canRead) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: ListTile(
        leading: const Icon(Icons.rule_folder_outlined),
        title: const Text('Regras do plano'),
        subtitle: const Text('Constantes vigentes: janelas, picos, frequência mínima, caps, idade, comorbidades — read-only'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/admin/plan-rules'),
      ),
    );
  }
}

class _CoachRuntimeEntry extends StatelessWidget {
  final bool canRead;
  const _CoachRuntimeEntry({required this.canRead});

  @override
  Widget build(BuildContext context) {
    if (!canRead) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: ListTile(
        leading: const Icon(Icons.tune_outlined),
        title: const Text('Coach Runtime'),
        subtitle: const Text('Distância entre cues, cooldowns, rotação Live, reconnect cap — parametrizar sem deploy'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/admin/coach-runtime'),
      ),
    );
  }
}

class _TechMetricsEntry extends StatelessWidget {
  final bool canRead;
  const _TechMetricsEntry({required this.canRead});

  @override
  Widget build(BuildContext context) {
    if (!canRead) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: ListTile(
        leading: const Icon(Icons.monitor_heart_outlined),
        title: const Text('TECH · Saúde & Custos'),
        subtitle: const Text('Healthz dos serviços, erros 24h/7d, custo LLM do dia'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/admin/tech'),
      ),
    );
  }
}

class _TokensEntry extends StatelessWidget {
  final bool canRead;
  const _TokensEntry({required this.canRead});

  @override
  Widget build(BuildContext context) {
    if (!canRead) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: ListTile(
        leading: const Icon(Icons.attach_money_outlined),
        title: const Text('Tokens & Custo LLM'),
        subtitle: const Text('Input/output, custo USD por dia, modelo, use case e top users'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/admin/tokens'),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;

  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: palette.primary),
        color: palette.surfaceAlt,
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: palette.primary,
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
