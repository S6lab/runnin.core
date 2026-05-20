import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

/// Conta & acesso enxuta:
///  - EMAIL: read-only (do Firebase Auth). Não trocável.
///  - TELEFONE: editável via re-verificação SMS (Firebase). Quer mais
///    segurança? Follow-up: confirmação por email (2FA). Hoje o re-link
///    direto do Firebase já garante posse do número.
///  - SAIR: signOut do Firebase + go /login
///  - EXCLUIR CONTA: DELETE /v1/users/me + signOut. Confirmação dupla.
class AccountAccessPage extends StatefulWidget {
  const AccountAccessPage({super.key});

  @override
  State<AccountAccessPage> createState() => _AccountAccessPageState();
}

class _AccountAccessPageState extends State<AccountAccessPage> {
  final _phoneCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  /// Número completo em E.164 montado pelo IntlPhoneField (Brasil default).
  String _completePhone = '';
  bool _phoneEditing = false;
  bool _codeRequested = false;
  bool _busy = false;
  String? _message;
  String? _error;
  String? _verificationId;
  ConfirmationResult? _confirmationResult;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendPhoneCode() async {
    // O IntlPhoneField já entrega o número em E.164 com o código do país.
    final phone = _completePhone.trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty || digits.length < 10) {
      setState(() {
        _error = 'Informe um telefone válido com DDD.';
        _message = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (kIsWeb) {
        _confirmationResult = await auth.signInWithPhoneNumber(phone);
        if (mounted) setState(() => _codeRequested = true);
      } else {
        await auth.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (cred) async {
            try {
              await auth.currentUser?.updatePhoneNumber(cred);
              if (mounted) {
                setState(() {
                  _message = 'Telefone atualizado.';
                  _phoneEditing = false;
                  _codeRequested = false;
                  _phoneCtrl.clear();
                  _smsCtrl.clear();
                });
              }
            } catch (e) {
              if (mounted) setState(() => _error = '$e');
            }
          },
          verificationFailed: (e) {
            if (mounted) {
              setState(() {
                _error = 'Erro: ${e.code}';
                _busy = false;
              });
            }
          },
          codeSent: (vid, _) {
            if (mounted) {
              setState(() {
                _verificationId = vid;
                _codeRequested = true;
                _busy = false;
              });
            }
          },
          codeAutoRetrievalTimeout: (vid) {
            _verificationId = vid;
          },
        );
        return;
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = 'Erro: ${e.code}');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPhoneCode() async {
    final code = _smsCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Código de 6 dígitos.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      PhoneAuthCredential? cred;
      if (kIsWeb) {
        final r = _confirmationResult;
        if (r == null) throw Exception('Fluxo não iniciado');
        await r.confirm(code);
      } else {
        final vid = _verificationId;
        if (vid == null) throw Exception('Fluxo não iniciado');
        cred = PhoneAuthProvider.credential(verificationId: vid, smsCode: code);
        await auth.currentUser?.updatePhoneNumber(cred);
      }
      if (mounted) {
        setState(() {
          _message = 'Telefone atualizado.';
          _phoneEditing = false;
          _codeRequested = false;
          _phoneCtrl.clear();
          _smsCtrl.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = 'Erro: ${e.code}');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    clearOnboardingCache();
    if (mounted) context.go('/login');
  }

  Future<void> _confirmAndDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text(
          'Vai apagar TUDO: perfil, plano, corridas, biometrias, notificações. '
          'Não tem volta. Você terá que criar uma conta nova se quiser usar de novo.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('EXCLUIR DEFINITIVAMENTE',
                style: context.runninType.labelMd.copyWith(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Server apaga doc do user + subcollections + Auth user
      await apiClient.delete<void>('/users/me');
      // Local: signOut + clear caches + login
      await FirebaseAuth.instance.signOut();
      clearOnboardingCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta excluída.')),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Falha ao excluir: $e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    final phone = user?.phoneNumber;
    // Se o login foi por telefone, o número é a credencial de acesso e não
    // pode ser trocado aqui (evita perda de acesso à conta).
    final loggedInWithPhone =
        user?.providerData.any((p) => p.providerId == 'phone') ?? false;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FigmaTopNav(
              breadcrumb: 'CONTA & ACESSO',
              showBackButton: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // EMAIL — read-only
                  _SectionLabel(label: 'EMAIL'),
                  const SizedBox(height: 8),
                  AppPanel(
                    child: Row(
                      children: [
                        Icon(Icons.email_outlined,
                            size: 18, color: palette.muted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            email?.isNotEmpty == true ? email! : 'sem email',
                            style: context.runninType.bodyMd.copyWith(color: palette.text, fontSize: 13),
                          ),
                        ),
                        Icon(Icons.lock_outline,
                            size: 14, color: palette.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Email não pode ser alterado — está vinculado ao seu cadastro.',
                    style: context.runninType.bodyXs,
                  ),
                  const SizedBox(height: 24),

                  // TELEFONE — trocável via SMS
                  _SectionLabel(label: 'TELEFONE'),
                  const SizedBox(height: 8),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 18, color: palette.muted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                phone?.isNotEmpty == true
                                    ? phone!
                                    : 'sem telefone cadastrado',
                                style:
                                    context.runninType.bodyMd.copyWith(color: palette.text, fontSize: 13),
                              ),
                            ),
                            if (loggedInWithPhone)
                              Icon(Icons.lock_outline,
                                  size: 14, color: palette.muted)
                            else
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                          _phoneEditing = !_phoneEditing;
                                          _codeRequested = false;
                                          _phoneCtrl.clear();
                                          _smsCtrl.clear();
                                          _completePhone = '';
                                          _error = null;
                                          _message = null;
                                        }),
                                child: Text(
                                  _phoneEditing ? 'CANCELAR' : 'TROCAR',
                                  style: context.runninType.labelCaps.copyWith(
                                    fontSize: 11,
                                    color: palette.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (loggedInWithPhone) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Você entrou com este telefone — ele é sua credencial de acesso e não pode ser alterado aqui.',
                            style: context.runninType.bodyXs.copyWith(color: palette.muted),
                          ),
                        ],
                        if (_phoneEditing && !loggedInWithPhone) ...[
                          const SizedBox(height: 14),
                          IntlPhoneField(
                            controller: _phoneCtrl,
                            enabled: !_codeRequested,
                            initialCountryCode: 'BR',
                            languageCode: 'pt',
                            style: TextStyle(color: palette.text),
                            dropdownTextStyle: TextStyle(color: palette.text),
                            dropdownIcon: Icon(Icons.arrow_drop_down, color: palette.muted),
                            invalidNumberMessage: 'Número inválido',
                            decoration: InputDecoration(
                              hintText: '11 99999-9999',
                              hintStyle: TextStyle(color: palette.muted),
                              counterText: '',
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: palette.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(color: palette.primary),
                              ),
                            ),
                            onChanged: (p) => _completePhone = p.completeNumber,
                          ),
                          if (!_codeRequested) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _sendPhoneCode,
                                child: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('ENVIAR CÓDIGO POR SMS'),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _smsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Código SMS',
                                hintText: '123456',
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _confirmPhoneCode,
                                child: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('CONFIRMAR NOVO TELEFONE'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Validação por SMS garante posse do número. Em breve: confirmação extra por email (2FA).',
                            style: context.runninType.bodyXs.copyWith(color: palette.muted),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    AppPanel(
                      padding: const EdgeInsets.all(12),
                      color: palette.error.withValues(alpha: 0.08),
                      borderColor: palette.error.withValues(alpha: 0.35),
                      child: Text(_error!,
                          style: context.runninType.bodySm.copyWith(color: palette.error)),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    AppPanel(
                      padding: const EdgeInsets.all(12),
                      color: palette.primary.withValues(alpha: 0.08),
                      borderColor: palette.primary.withValues(alpha: 0.35),
                      child: Text(_message!,
                          style: context.runninType.bodySm.copyWith(color: palette.primary)),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // SAIR
                  GestureDetector(
                    onTap: _busy ? null : _signOut,
                    child: AppPanel(
                      child: Row(
                        children: [
                          Icon(Icons.logout,
                              size: 16, color: palette.muted),
                          const SizedBox(width: 12),
                          Text(
                            'SAIR DA CONTA',
                            style: context.runninType.labelMd.copyWith(
                              fontWeight: FontWeight.w500,
                              color: palette.text,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // EXCLUIR CONTA (vermelho, double-confirm)
                  GestureDetector(
                    onTap: _busy ? null : _confirmAndDeleteAccount,
                    child: AppPanel(
                      color: palette.error.withValues(alpha: 0.06),
                      borderColor: palette.error.withValues(alpha: 0.4),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: palette.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EXCLUIR MINHA CONTA',
                                  style: context.runninType.labelMd.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: palette.error,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Apaga tudo. Sem volta.',
                                  style: context.runninType.bodyXs,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Text(
      label,
      style: context.runninType.labelCaps.copyWith(
        fontSize: 11,
        color: palette.muted,
        letterSpacing: 1.2,
      ),
    );
  }
}
