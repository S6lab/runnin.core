import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_shared.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _phoneMode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      await UserRemoteDatasource().provisionMe();
    } catch (e) {
      setState(() {
        _error = 'Erro ao fazer login. Tente novamente.';
        _loading = false;
      });
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInAnonymously();
      await UserRemoteDatasource().provisionMe();
    } catch (_) {
      setState(() {
        _error = 'Não foi possível entrar no modo anônimo.';
        _loading = false;
      });
    }
  }

  Future<void> _beginPhoneAuth() async {
    setState(() { _loading = true; _error = null; });
    final phoneNumber = _normalizePhoneNumber(_phoneController.text.trim());
    if (phoneNumber == null) {
      setState(() {
        _error = 'Informe um telefone valido com DDD.';
        _loading = false;
      });
      return;
    }

    try {
      final auth = FirebaseAuth.instance;
      if (kIsWeb) {
        await auth.signInWithPhoneNumber(phoneNumber);
      } else {
        await auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (credential) async {
            try {
              await auth.signInWithCredential(credential);
              await UserRemoteDatasource().provisionMe();
            } catch (_) {}
          },
          verificationFailed: (e) {
            if (!mounted) return;
            setState(() {
              _error = _friendlyAuthError(e);
              _loading = false;
            });
          },
          codeSent: (verificationId, resendToken) {
            if (!mounted) return;
            setState(() {
              _phoneMode = true;
              _loading = false;
              _error = null;
            });
          },
          codeAutoRetrievalTimeout: (verificationId) {
            _phoneVerificationId = verificationId;
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyAuthError(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível enviar o código agora.';
        _loading = false;
      });
    }
  }

  Future<void> _confirmPhoneCode() async {
    final code = _smsCodeController.text.trim();
    if (code.length < 6) {
      setState(() {
        _error = 'Digite o código de 6 dígitos recebido por SMS.';
      });
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final auth = FirebaseAuth.instance;
      if (kIsWeb) {
        final confirmation = _phoneConfirmationResult;
        if (confirmation == null) {
          throw FirebaseAuthException(code: 'invalid-verification-id');
        }
        await confirmation.confirm(code);
      } else {
        final verificationId = _phoneVerificationId;
        if (verificationId == null) {
          throw FirebaseAuthException(code: 'invalid-verification-id');
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        );
        await auth.signInWithCredential(credential);
      }
      await UserRemoteDatasource().provisionMe();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyAuthError(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível validar o código agora.';
        _loading = false;
      });
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    final code = e.code;
    if (code == 'invalid-verification-code') return 'Código inválido.';
    if (code == 'expired-verification-code') return 'Código expirado.';
    if (code == 'invalid-phone-number') return 'Número de telefone inválido.';
    if (code == 'quota-exceeded') return 'Cota excedida. Tente novamente mais tarde.';
    if (code == 'session-expired') return 'Sessão expirada.';
    return 'Erro ao autenticar. Tente novamente.';
  }

  String? _normalizePhoneNumber(String input) {
    final digits = RegExp(r'[0-9]').allMatches(input).map((m) => m.group(0)).join();
    if (digits.length < 10 || digits.length > 11) return null;
    if (digits.length == 10) {
      final ddd = digits.substring(0, 2);
      final number = digits.substring(2);
      return '+55 $ddd $number';
    }
    final ddd = digits.substring(0, 2);
    final number = digits.substring(2, 7) + digits.substring(7);
    return '+55 $ddd $number';
  }

  String? _phoneVerificationId;
  dynamic _phoneConfirmationResult;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(23.992),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                Text(
                  '// LOGIN',
                  style: context.runninType.labelMd.copyWith(color: palette.primary),
                ),
                const SizedBox(height: 14),
                Text('Entre na corrida', style: context.runninType.displayMd),
                const SizedBox(height: 28),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OnboardingInlineNotice(
                      text: _error!,
                      color: palette.error,
                    ),
                  ),
                if (!_phoneMode) ...[
                  FigmaGoogleSignInButton(
                    onPressed: _loading ? null : _signInWithGoogle,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loading ? null : _signInAnonymously,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: BorderSide(color: palette.border, width: 1.735),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: const Text('CONTINUAR ANONIMAMENTE'),
                  ),
                  const SizedBox(height: 28),
                  const FigmaFormFieldLabel(text: 'OU DIGITE SEU TELEFONE'),
                  const SizedBox(height: 8),
                  FigmaFormTextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    placeholder: '+55 (11) 99999-9999',
                    maxLength: 14,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _beginPhoneAuth,
                      child: const Text('ENVIA CÓDIGO POR SMS'),
                    ),
                  ),
                ] else ...[
                  const FigmaFormFieldLabel(text: 'TELEFONE'),
                  const SizedBox(height: 8),
                  FigmaFormTextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    placeholder: '+55 (11) 99999-9999',
                    maxLength: 14,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const FigmaFormFieldLabel(text: 'CODIGO OTP'),
                  const SizedBox(height: 8),
                  FigmaOtpTextField(
                    controller: _smsCodeController,
                    enabled: true,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _confirmPhoneCode,
                      child: const Text('ENTRAR'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
