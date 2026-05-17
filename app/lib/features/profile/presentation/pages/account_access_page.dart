import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/otp_resend_button.dart';

class AccountAccessPage extends StatefulWidget {
  const AccountAccessPage({super.key});

  @override
  State<AccountAccessPage> createState() => _AccountAccessPageState();
}

class _AccountAccessPageState extends State<AccountAccessPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();
  bool _submitting = false;
  bool _sendingPhoneCode = false;
  bool _verifyingPhoneCode = false;
  String? _phoneVerificationId;
  int? _phoneResendToken;
  ConfirmationResult? _phoneConfirmationResult;
  String? _message;
  String? _error;
  final _resendCtrl = OtpResendController();

  @override
  void initState() {
    super.initState();
    // Web: ao voltar do redirect do Google Auth, processa o resultado.
    // No-op se a pessoa não veio de um redirect. Vital pra fluxo
    // signInWithRedirect/linkWithRedirect (evita CORS do popup).
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final result = await FirebaseAuth.instance.getRedirectResult();
          if (result.user != null && mounted) {
            setState(() => _message = 'Conta Google vinculada.');
          }
        } catch (e) {
          if (mounted) setState(() => _error = 'Erro no retorno do Google: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _smsCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectEmailPassword() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.length < 6) {
      setState(() {
        _error = 'Preencha um e-mail válido e uma senha com pelo menos 6 caracteres.';
        _message = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      if (user != null && user.isAnonymous) {
        await user.linkWithCredential(credential);
        _message = 'Conta protegida com e-mail e senha.';
      } else {
        try {
          await auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          _message = 'Login com e-mail concluído.';
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            await auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            _message = 'Conta criada com e-mail e senha.';
          } else {
            rethrow;
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
      });
    } catch (_) {
      setState(() {
        _error = 'Não foi possível conectar sua conta agora.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _connectGoogle() async {
    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      OAuthCredential? credential;

      if (kIsWeb) {
        // Redirect em vez de popup: popup quebra com CORS em browsers
        // novos (Chrome 95+ aplica COOP same-origin que bloqueia
        // postMessage entre janelas). Redirect faz navegação full-page
        // e o retorno é capturado em initState via getRedirectResult().
        final provider = GoogleAuthProvider();
        if (user != null && user.isAnonymous) {
          await user.linkWithRedirect(provider);
        } else {
          await auth.signInWithRedirect(provider);
        }
        // Não há mais código após o redirect — a página é recarregada.
        return;
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _submitting = false);
          return;
        }
        final auth_ = await googleUser.authentication;
        credential = GoogleAuthProvider.credential(
          accessToken: auth_.accessToken,
          idToken: auth_.idToken,
        );
        if (user != null && user.isAnonymous) {
          await user.linkWithCredential(credential);
        } else {
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
      }

      if (!mounted) return;
      setState(() {
        _message = user?.isAnonymous == true
            ? 'Conta Google vinculada. Seus dados foram preservados.'
            : 'Login com Google concluído.';
      });
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível conectar com Google agora.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está em uso. Tente entrar com ele ou use outro.';
      case 'provider-already-linked':
        return 'Seu e-mail já está vinculado a esta conta.';
      case 'invalid-email':
        return 'O e-mail informado não é válido.';
      case 'weak-password':
        return 'Escolha uma senha mais forte.';
      case 'credential-already-in-use':
        return 'Essa credencial já está vinculada a outra conta.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha inválidos.';
      case 'invalid-phone-number':
        return 'O número de telefone não é válido.';
      case 'session-expired':
        return 'O código expirou. Solicite um novo SMS.';
      case 'invalid-verification-code':
        return 'O código informado está incorreto.';
      case 'operation-not-allowed':
        return 'Esse método de login ainda não está habilitado no Firebase.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
      default:
        return 'Não foi possível concluir essa operação agora.';
    }
  }

  String? _normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('+') && digits.length >= 12) return digits;
    if (digits.startsWith('55') && digits.length >= 12) return '+$digits';
    if (digits.length >= 10 && digits.length <= 11) return '+55$digits';
    return null;
  }

  Future<void> _sendPhoneCode({bool resend = false}) async {
    final phoneNumber = _normalizePhoneNumber(_phoneCtrl.text.trim());
    if (phoneNumber == null) {
      setState(() {
        _error = 'Informe um telefone válido com DDD. Ex.: 11999999999';
        _message = null;
      });
      return;
    }

    setState(() {
      _sendingPhoneCode = true;
      _error = null;
      _message = null;
      if (!resend) {
        _phoneVerificationId = null;
        _phoneConfirmationResult = null;
        _phoneResendToken = null;
      }
    });

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (kIsWeb) {
        if (user != null && user.isAnonymous) {
          _phoneConfirmationResult = await user.linkWithPhoneNumber(phoneNumber);
        } else {
          _phoneConfirmationResult = await auth.signInWithPhoneNumber(phoneNumber);
        }
        if (resend && mounted) _resendCtrl.restart();
      } else {
        await auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          forceResendingToken: _phoneResendToken,
          verificationCompleted: (credential) async {
            try {
              if (user != null && user.isAnonymous) {
                await user.linkWithCredential(credential);
                if (!mounted) return;
                setState(() {
                  _message = 'Telefone vinculado com sucesso.';
                  _error = null;
                });
              } else {
                await auth.signInWithCredential(credential);
                if (!mounted) return;
                setState(() {
                  _message = 'Login com telefone concluído.';
                  _error = null;
                });
              }
            } on FirebaseAuthException catch (e) {
              if (!mounted) return;
              setState(() {
                _error = _friendlyAuthError(e);
              });
            }
          },
          verificationFailed: (e) {
            if (!mounted) return;
            setState(() {
              _error = _friendlyAuthError(e);
              _sendingPhoneCode = false;
            });
          },
          codeSent: (verificationId, resendToken) {
            if (!mounted) return;
            setState(() {
              _phoneVerificationId = verificationId;
              _phoneResendToken = resendToken;
              _message = resend ? 'Novo código enviado por SMS.' : 'Código enviado por SMS.';
              _sendingPhoneCode = false;
            });
            _resendCtrl.restart();
          },
          codeAutoRetrievalTimeout: (verificationId) {
            _phoneVerificationId = verificationId;
          },
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _message = 'Código enviado por SMS.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
      });
    } catch (_) {
      setState(() {
        _error = 'Não foi possível enviar o código agora.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingPhoneCode = false;
        });
      }
    }
  }

  Future<void> _confirmPhoneCode() async {
    final code = _smsCodeCtrl.text.trim();
    if (code.length < 6) {
      setState(() {
        _error = 'Digite o código de 6 dígitos recebido por SMS.';
        _message = null;
      });
      return;
    }

    setState(() {
      _verifyingPhoneCode = true;
      _error = null;
      _message = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (kIsWeb) {
        final confirmation = _phoneConfirmationResult;
        if (confirmation == null) {
          throw FirebaseAuthException(
            code: 'invalid-verification-id',
            message: 'Fluxo de verificação não iniciado.',
          );
        }
        await confirmation.confirm(code);
      } else {
        final verificationId = _phoneVerificationId;
        if (verificationId == null) {
          throw FirebaseAuthException(
            code: 'invalid-verification-id',
            message: 'Fluxo de verificação não iniciado.',
          );
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        );
        if (user != null && user.isAnonymous) {
          await user.linkWithCredential(credential);
        } else {
          await auth.signInWithCredential(credential);
        }
      }

      if (!mounted) return;
      setState(() {
        _message = 'Telefone conectado com sucesso.';
        _smsCodeCtrl.clear();
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyAuthError(e);
      });
    } catch (_) {
      setState(() {
        _error = 'Não foi possível validar o código agora.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _verifyingPhoneCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;
    final statusTitle = isAnonymous ? 'Modo anônimo ativo' : 'Conta conectada';
    final statusBody = isAnonymous
        ? 'Você pode continuar usando o app assim, mas vale proteger seu acesso para não perder seus dados em outro dispositivo.'
        : 'Seu acesso já está vinculado. Você pode adicionar outro método para facilitar entrada e recuperação da conta.';

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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'Métodos de login e vínculo entre dispositivos',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: palette.muted,
                  height: 1.5,
                ),
              ),
            ),
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
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isAnonymous
                                    ? palette.secondary
                                    : palette.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              statusTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          statusBody,
                          style: TextStyle(
                            color: palette.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACESSO 1',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.primary,
                            letterSpacing: 0.12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'E-mail e senha',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAnonymous
                              ? 'Ideal para proteger sua conta atual e continuar de onde parou.'
                              : 'Entre com e-mail ou crie uma senha para usar sua conta em outros dispositivos.',
                          style: TextStyle(
                            color: palette.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            hintText: 'voce@exemplo.com',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Senha',
                            hintText: 'Mínimo de 6 caracteres',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _connectEmailPassword,
                            child: _submitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: palette.background,
                                    ),
                                  )
                                : Text(
                                    isAnonymous
                                        ? 'VINCULAR E-MAIL E SENHA'
                                        : 'ENTRAR / CRIAR COM E-MAIL',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _submitting ? null : _connectGoogle,
                            icon: const Icon(Icons.account_circle_outlined, size: 18),
                            label: Text(isAnonymous ? 'VINCULAR CONTA GOOGLE' : 'ENTRAR COM GOOGLE'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: palette.border, width: 1.041),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACESSO 2',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.secondary,
                            letterSpacing: 0.12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Telefone',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Conecte seu número para recuperar acesso e proteger seus dados. Se estiver anônimo, o telefone será vinculado à conta atual.',
                          style: TextStyle(
                            color: palette.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Telefone',
                            hintText: '11999999999',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _sendingPhoneCode ? null : _sendPhoneCode,
                            child: _sendingPhoneCode
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: palette.primary,
                                    ),
                                  )
                                : const Text('ENVIAR CÓDIGO'),
                          ),
                        ),
                        if (_phoneConfirmationResult != null ||
                            _phoneVerificationId != null) ...[
                          const SizedBox(height: 12),
                          AppPanel(
                            padding: const EdgeInsets.all(12),
                            color: palette.surfaceAlt,
                            borderColor: palette.secondary.withValues(alpha: 0.4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.sms_outlined,
                                  size: 18,
                                  color: palette.secondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'O código foi enviado. Digite os 6 números recebidos por SMS para concluir o vínculo.',
                                    style: TextStyle(
                                      color: palette.text.withValues(alpha: 0.84),
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _smsCodeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Código SMS',
                              hintText: '123456',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  _verifyingPhoneCode ? null : _confirmPhoneCode,
                              child: _verifyingPhoneCode
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: palette.background,
                                      ),
                                    )
                                  : const Text('CONFIRMAR CÓDIGO'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OtpResendButton(
                            controller: _resendCtrl,
                            onResend: () => _sendPhoneCode(resend: true),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AppPanel(
                      padding: const EdgeInsets.all(12),
                      color: palette.error.withValues(alpha: 0.08),
                      borderColor: palette.error.withValues(alpha: 0.35),
                      child: Text(
                        _error!,
                        style: TextStyle(color: palette.error, fontSize: 13),
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    AppPanel(
                      padding: const EdgeInsets.all(12),
                      color: palette.primary.withValues(alpha: 0.08),
                      borderColor: palette.primary.withValues(alpha: 0.35),
                      child: Text(
                        _message!,
                        style: TextStyle(color: palette.primary, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
