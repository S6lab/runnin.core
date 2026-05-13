import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/otp_resend_button.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _ds = UserRemoteDatasource();
  final _phoneCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();

  static const _totalSteps = 4;
  static const _loginStep = 3;

  int _step = 0;
  bool _authLoading = false;
  bool _submitting = false;
  String? _phoneVerificationId;
  int? _phoneResendToken;
  ConfirmationResult? _phoneConfirmationResult;
  String? _error;
  String? _message;
  final _resendCtrl = OtpResendController();

  static const _introSlides = [
    _IntroSlide(
      code: 'SLIDE_01',
      number: '01',
      title: 'Seu personal trainer de IA',
      body:
          'Um coach que te conhece, planeja seu treino e acompanha cada quilometro. Antes, durante e depois da corrida.',
      features: [
        _IntroFeature(
          Icons.psychology_alt_outlined,
          'Inteligencia adaptativa',
          'O plano evolui com voce a cada corrida',
        ),
        _IntroFeature(
          Icons.mic_none_outlined,
          'Coach por voz',
          'Orientacao em tempo real, sem tirar o celular do bolso',
        ),
        _IntroFeature(
          Icons.analytics_outlined,
          'Analise completa',
          'Metricas, zonas cardiacas, benchmark e tendencias',
        ),
      ],
    ),
    _IntroSlide(
      code: 'SLIDE_02',
      number: '02',
      title: 'Te guia por voz, em tempo real',
      body:
          'Pace, motivacao, dicas. O Coach fala com voce durante a corrida, sem tirar o celular do bolso.',
      features: [
        _IntroFeature(
          Icons.bolt_outlined,
          'Alertas inteligentes',
          'Avisa quando sair da zona de pace ou BPM alvo',
        ),
        _IntroFeature(
          Icons.directions_run_outlined,
          'Splits ao vivo',
          'Comentarios a cada km sobre seu desempenho',
        ),
        _IntroFeature(
          Icons.music_note_outlined,
          'Integra com musica',
          'Volume baixa automaticamente durante orientacoes',
        ),
      ],
    ),
    _IntroSlide(
      code: 'SLIDE_03',
      number: '03',
      title: 'Evolua e conquiste',
      body:
          'Gamificacao, metas e recompensas que te fazem voltar todo dia. Nao e so correr, e um jogo de evolucao pessoal.',
      features: [
        _IntroFeature(
          Icons.emoji_events_outlined,
          'Badges e XP',
          'Conquiste marcos, suba de nivel, desbloqueie recompensas',
        ),
        _IntroFeature(
          Icons.trending_up_outlined,
          'Benchmark',
          'Compare seu desempenho com corredores do seu nivel',
        ),
        _IntroFeature(
          Icons.calendar_month_outlined,
          'Periodizacao IA',
          'Planejamento mensal/semanal que se adapta ao progresso',
        ),
      ],
    ),
  ];



  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_handleFieldChange);
    _smsCodeCtrl.addListener(_handleFieldChange);
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_handleFieldChange);
    _smsCodeCtrl.removeListener(_handleFieldChange);
    _phoneCtrl.dispose();
    _smsCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _authLoading = true;
      _error = null;
      _message = null;
    });

    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _authLoading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      await _afterAuthenticated();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyAuthError(e);
        _authLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Nao foi possivel entrar com Google agora.';
        _authLoading = false;
      });
    }
  }

  Future<void> _handlePhonePrimary() async {
    if (_phoneConfirmationResult != null || _phoneVerificationId != null) {
      await _confirmPhoneCode();
    } else {
      await _sendPhoneCode();
    }
  }

  Future<void> _sendPhoneCode({bool resend = false}) async {
    final phoneNumber = _normalizePhoneNumber(_phoneCtrl.text.trim());
    if (phoneNumber == null) {
      setState(() {
        _error = 'Informe um telefone valido com DDD. Ex.: 11999999999';
        _message = null;
      });
      return;
    }

    setState(() {
      _authLoading = true;
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
      if (kIsWeb) {
        _phoneConfirmationResult = await auth.signInWithPhoneNumber(
          phoneNumber,
        );
        if (!mounted) return;
        setState(() {
          _message = resend ? 'Novo codigo enviado por SMS.' : 'Codigo enviado por SMS.';
          _authLoading = false;
        });
        if (resend) _resendCtrl.restart();
      } else {
        await auth.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          forceResendingToken: _phoneResendToken,
          verificationCompleted: (credential) async {
            try {
              await auth.signInWithCredential(credential);
              await _afterAuthenticated();
            } on FirebaseAuthException catch (e) {
              if (!mounted) return;
              setState(() {
                _error = _friendlyAuthError(e);
                _authLoading = false;
              });
            }
          },
          verificationFailed: (e) {
            if (!mounted) return;
            setState(() {
              _error = _friendlyAuthError(e);
              _authLoading = false;
            });
          },
          codeSent: (verificationId, resendToken) {
            if (!mounted) return;
            setState(() {
              _phoneVerificationId = verificationId;
              _phoneResendToken = resendToken;
              _message = resend ? 'Novo codigo enviado por SMS.' : 'Codigo enviado por SMS.';
              _authLoading = false;
            });
            _resendCtrl.restart();
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
        _authLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Nao foi possivel enviar o codigo agora.';
        _authLoading = false;
      });
    }
  }

  Future<void> _confirmPhoneCode() async {
    final code = _smsCodeCtrl.text.trim();
    if (code.length < 6) {
      setState(() {
        _error = 'Digite o codigo de 6 digitos recebido por SMS.';
        _message = null;
      });
      return;
    }

    setState(() {
      _authLoading = true;
      _error = null;
      _message = null;
    });

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
      await _afterAuthenticated();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyAuthError(e);
        _authLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Nao foi possivel validar o codigo agora.';
        _authLoading = false;
      });
    }
  }

  Future<void> _afterAuthenticated() async {
    final profile = await _ds.provisionMe();
    if (!mounted) return;

    if (profile.onboarded) {
      markOnboardingDone();
      context.go('/home');
      return;
    }

    markOnboardingPending();
    if (mounted) context.go('/assessment');
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
              _StepDots(total: _totalSteps, current: _step),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = context.runninPalette;
    final canGoBack = _step > 0;
    final showSkip = _step < _loginStep;

    return Row(
      children: [
        if (canGoBack)
          OutlinedButton(
            onPressed: _authLoading || _submitting
                ? null
                : () => setState(() => _step--),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(86, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('< VOLTAR'),
          )
        else
          const SizedBox(width: 86, height: 38),
        const Spacer(),
        Text('RUNIN', style: context.runninType.labelMd),
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
        if (showSkip) ...[
          const SizedBox(width: 18),
          TextButton(
            onPressed: _authLoading || _submitting ? null : _skipIntro,
            child: const Text('PULAR'),
          ),
        ] else
          const SizedBox(width: 66),
      ],
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
      case 1:
      case 2:
        return _StepIntro(slide: _introSlides[_step]);
      case _loginStep:
        return _StepLogin(
          phoneController: _phoneCtrl,
          smsCodeController: _smsCodeCtrl,
          codeRequested:
              _phoneConfirmationResult != null || _phoneVerificationId != null,
          loading: _authLoading,
          onGoogleSignIn: _signInWithGoogle,
          resendController: _resendCtrl,
          onResendCode: () => _sendPhoneCode(resend: true),
          error: _error,
          message: _message,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNav(BuildContext context) {
    final palette = context.runninPalette;

    final isLogin = _step == _loginStep;
    final label = isLogin
        ? (_phoneConfirmationResult != null || _phoneVerificationId != null
              ? 'VALIDAR CODIGO'
              : 'ENVIAR CODIGO')
        : 'CONTINUAR';

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _canProceed()
            ? (isLogin ? _handlePhonePrimary : _nextStep)
            : null,
        child: _authLoading
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
    );
  }

  bool _canProceed() {
    if (_authLoading) return false;

    if (_step == _loginStep) {
      if (_phoneConfirmationResult != null || _phoneVerificationId != null) {
        return _smsCodeCtrl.text.trim().length >= 6;
      }
      return _normalizePhoneNumber(_phoneCtrl.text.trim()) != null;
    }
    return true;
  }

  String? _normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('+') && digits.length >= 12) return digits;
    if (digits.startsWith('55') && digits.length >= 12) return '+$digits';
    if (digits.length >= 10 && digits.length <= 11) return '+55$digits';
    return null;
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'O numero de telefone nao e valido.';
      case 'session-expired':
        return 'O codigo expirou. Solicite um novo SMS.';
      case 'invalid-verification-code':
        return 'O codigo informado esta incorreto.';
      case 'operation-not-allowed':
        return 'Esse metodo de login ainda nao esta habilitado no Firebase.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
      case 'popup-closed-by-user':
        return 'Login cancelado antes de concluir.';
      default:
        return 'Nao foi possivel concluir o login agora.';
    }
  }

  void _handleFieldChange() {
    if (!mounted) return;
    setState(() {
      _error = null;
    });
  }

  void _skipIntro() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _step = _loginStep);
    } else {
      context.go('/assessment');
    }
  }

  void _nextStep() => setState(() => _step++);
}

class _IntroSlide {
  final String code;
  final String number;
  final String title;
  final String body;
  final List<_IntroFeature> features;

  const _IntroSlide({
    required this.code,
    required this.number,
    required this.title,
    required this.body,
    required this.features,
  });
}

class _IntroFeature {
  final IconData icon;
  final String title;
  final String body;

  const _IntroFeature(this.icon, this.title, this.body);
}

class _StepIntro extends StatelessWidget {
  final _IntroSlide slide;

  const _StepIntro({required this.slide});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          Text(
            '// ${slide.code}',
            style: context.runninType.labelMd.copyWith(color: palette.primary),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(slide.title, style: context.runninType.displayLg),
              ),
              const SizedBox(width: 12),
              Text(
                slide.number,
                style: context.runninType.labelMd.copyWith(
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            slide.body,
            style: context.runninType.bodyMd.copyWith(
              color: palette.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 26),
          ...slide.features.map(
            (feature) => AppPanel(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(feature.icon, color: palette.primary, size: 19),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.title,
                          style: context.runninType.labelMd.copyWith(
                            color: palette.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feature.body,
                          style: context.runninType.bodySm.copyWith(
                            color: palette.muted,
                            height: 1.35,
                          ),
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
    );
  }
}

class _StepLogin extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController smsCodeController;
  final bool codeRequested;
  final bool loading;
  final VoidCallback onGoogleSignIn;
  final OtpResendController resendController;
  final Future<void> Function() onResendCode;
  final String? error;
  final String? message;

  const _StepLogin({
    required this.phoneController,
    required this.smsCodeController,
    required this.codeRequested,
    required this.loading,
    required this.onGoogleSignIn,
    required this.resendController,
    required this.onResendCode,
    required this.error,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return SingleChildScrollView(
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
          _FieldLabel('TELEFONE'),
          const SizedBox(height: 8),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              LengthLimitingTextInputFormatter(14),
            ],
            decoration: const InputDecoration(hintText: '+55 (11) 99999-9999'),
          ),
          const SizedBox(height: 18),
          _FieldLabel('CODIGO OTP'),
          const SizedBox(height: 8),
          TextField(
            controller: smsCodeController,
            enabled: codeRequested,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(hintText: '_  _  _  _  _  _'),
          ),
          if (codeRequested) ...[
            const SizedBox(height: 8),
            OtpResendButton(
              controller: resendController,
              onResend: onResendCode,
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: loading ? null : onGoogleSignIn,
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'G',
                          style: TextStyle(
                            color: palette.secondary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Google Sign-In'),
                      ],
                    ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            _InlineNotice(text: message!, color: palette.primary),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            _InlineNotice(text: error!, color: palette.error),
          ],
        ],
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

class _InlineNotice extends StatelessWidget {
  final String text;
  final Color color;

  const _InlineNotice({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(12),
      color: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.35),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
