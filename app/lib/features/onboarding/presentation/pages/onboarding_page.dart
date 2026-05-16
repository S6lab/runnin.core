import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/figma/export.dart';
import 'package:runnin/shared/widgets/otp_resend_button.dart';

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
  final _phoneCtrl = TextEditingController();
  final _smsCodeCtrl = TextEditingController();
  final _medicalOtherCtrl = TextEditingController();
  final Set<String> _medicalConditions = {};

  static const _totalSteps = 12;
  static const _loadingStep = _totalSteps - 1;
  static const _loginStep = 3;
  static const _firstAssessmentStep = 4;

  int _step = 0;
  String _level = 'iniciante';
  String _goal = 'Completar 10K';
  int _frequency = 4;
  bool _hasWearable = false;
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

  static const _levels = [
    ('iniciante', 'Iniciante', 'Nunca corri ou estou voltando agora'),
    ('intermediario', 'Intermediario', 'Corro regularmente'),
    ('avancado', 'Avancado', 'Treino estruturado'),
  ];

  static const _goals = [
    'Saúde e bem-estar',
    'Perder peso',
    'Completar 5K',
    'Completar 10K',
    'Meia maratona (21K)',
    'Maratona (42K)',
    'Ultramaratona',
    'Triathlon',
  ];

  static const _wearableOptions = [
    (
      true,
      'Tenho wearable',
      'Vamos marcar a preferencia, mas a integracao ainda precisa ser conectada',
    ),
    (false, 'Depois', 'Nenhum dado sera tratado como conectado por enquanto'),
  ];

  static const _medicalOptions = [
    'Hipertensao',
    'Diabetes tipo 2',
    'Asma',
    'Historico de AVC',
    'Problemas cardiacos',
    'Lesao no joelho',
    'Lesao no tornozelo',
    'Hernia de disco',
    'Toma anticoagulante',
    'Toma betabloqueador',
    'Toma insulina',
    'Artrose',
    'Fibromialgia',
    'Ansiedade/depressao',
    'Cirurgia recente (<6m)',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_handleFieldChange);
    _birthDateCtrl.addListener(_handleFieldChange);
    _weightCtrl.addListener(_handleFieldChange);
    _heightCtrl.addListener(_handleFieldChange);
    _phoneCtrl.addListener(_handleFieldChange);
    _smsCodeCtrl.addListener(_handleFieldChange);
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_handleFieldChange);
    _birthDateCtrl.removeListener(_handleFieldChange);
    _weightCtrl.removeListener(_handleFieldChange);
    _heightCtrl.removeListener(_handleFieldChange);
    _phoneCtrl.removeListener(_handleFieldChange);
    _smsCodeCtrl.removeListener(_handleFieldChange);
    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _phoneCtrl.dispose();
    _smsCodeCtrl.dispose();
    _medicalOtherCtrl.dispose();
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
    setState(() {
      _step = _firstAssessmentStep;
      _authLoading = false;
      _message = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_canProceed() || _submitting) return;
    if (FirebaseAuth.instance.currentUser == null) {
      setState(() {
        _step = _loginStep;
        _error = 'Entre para salvar seu plano.';
      });
      return;
    }

    setState(() {
      _step = _loadingStep;
      _error = null;
      _submitting = true;
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
        medicalConditions: _medicalConditions.toList()..sort(),
      );
      markOnboardingDone();
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao salvar perfil. Tente novamente.';
          _step = _loadingStep - 1;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          FigmaOnboardingTopProgressBar(total: 13, currentIndex: _step),
          Expanded(
            child: SafeArea(
              top: false,
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
                    FigmaOnboardingPageIndicator(total: 13, currentIndex: _step),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final palette = context.runninPalette;
    final canGoBack = _step > 0 && _step != _loadingStep;
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
      case 4:
        return _StepLevel(
          selected: _level,
          levels: _levels,
          onSelect: (value) => setState(() => _level = value),
        );
      case 5:
        return _StepIdentity(
          nameController: _nameCtrl,
          birthDateController: _birthDateCtrl,
        );
      case 6:
        return _StepBody(
          weightController: _weightCtrl,
          heightController: _heightCtrl,
        );
      case 7:
        return _StepMedicalConditions(
          selected: _medicalConditions,
          options: _medicalOptions,
          otherController: _medicalOtherCtrl,
          onToggle: _toggleMedicalCondition,
          onAddOther: _addOtherMedicalCondition,
        );
      case 8:
        return _StepGoal(
          goals: _goals,
          selectedGoal: _goal,
          onGoalSelect: (value) => setState(() => _goal = value),
        );
      case 9:
        return _StepFrequency(
          frequency: _frequency,
          onFreqChange: (value) => setState(() => _frequency = value),
        );
      case 10:
        return _StepWearable(
          selected: _hasWearable,
          options: _wearableOptions,
          onSelect: (value) => setState(() => _hasWearable = value),
        );
      case _loadingStep:
        return const _StepGeneratingPlan();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNav(BuildContext context) {
    final palette = context.runninPalette;
    if (_step == _loadingStep) return const SizedBox.shrink();

    final isLastDataStep = _step == _loadingStep - 1;
    final isLogin = _step == _loginStep;
    final label = isLogin
        ? (_phoneConfirmationResult != null || _phoneVerificationId != null
              ? 'VALIDAR CODIGO'
              : 'ENVIAR CODIGO')
        : isLastDataStep
        ? 'CRIAR MEU PLANO'
        : 'CONTINUAR';

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _canProceed()
                ? (isLogin
                      ? _handlePhonePrimary
                      : isLastDataStep
                      ? _submit
                      : _nextStep)
                : null,
            child: _authLoading || _submitting
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
        ),
        if (_step == 7)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pode pular se preferir. Voce pode adicionar depois no Perfil.',
              style: context.runninType.bodySm.copyWith(color: palette.muted),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  bool _canProceed() {
    if (_authLoading || _submitting) return false;

    switch (_step) {
      case _loginStep:
        if (_phoneConfirmationResult != null || _phoneVerificationId != null) {
          return _smsCodeCtrl.text.trim().length >= 6;
        }
        return _normalizePhoneNumber(_phoneCtrl.text.trim()) != null;
      case 5:
        return _nameCtrl.text.trim().isNotEmpty &&
            _isValidBirthDate(_birthDateCtrl.text.trim());
      case 6:
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

  void _toggleMedicalCondition(String value) {
    setState(() {
      if (_medicalConditions.contains(value)) {
        _medicalConditions.remove(value);
      } else {
        _medicalConditions.add(value);
      }
    });
  }

  void _addOtherMedicalCondition() {
    final value = _medicalOtherCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _medicalConditions.add(value);
      _medicalOtherCtrl.clear();
    });
  }

  void _handleFieldChange() {
    if (!mounted) return;
    setState(() {
      _error = null;
    });
  }

  void _skipIntro() {
    setState(() {
      _step = FirebaseAuth.instance.currentUser == null
          ? _loginStep
          : _firstAssessmentStep;
    });
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
          _StepCode('ASSESSMENT_02'),
          const SizedBox(height: 12),
          Text('Como te chamo?', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Nome e data de nascimento ajudam o Coach a personalizar comunicacao, zonas e progressao.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          _FieldLabel('SEU NOME'),
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
          _FieldLabel('DATA DE NASCIMENTO'),
          const SizedBox(height: 8),
          TextField(
            controller: birthDateController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
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
        _StepCode('ASSESSMENT_01'),
        const SizedBox(height: 12),
        Text('Qual seu nivel atual?', style: context.runninType.displayMd),
        const SizedBox(height: 10),
        Text(
          'O Coach adapta intensidade, volume e progressao ao seu nivel.',
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
              child: Text(
                '${level.$2} - ${level.$3}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? palette.primary : palette.text,
                ),
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
          _StepCode('ASSESSMENT_03'),
          const SizedBox(height: 12),
          Text('Peso e altura', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Usamos isso para estimar gasto calorico, zonas e carga de impacto.',
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

class _StepMedicalConditions extends StatelessWidget {
  final Set<String> selected;
  final List<String> options;
  final TextEditingController otherController;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddOther;

  const _StepMedicalConditions({
    required this.selected,
    required this.options,
    required this.otherController,
    required this.onToggle,
    required this.onAddOther,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final customOptions = selected.where((item) => !options.contains(item));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepCode('ASSESSMENT_04'),
          const SizedBox(height: 12),
          Text('Informacoes de saude', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Opcional, mas importante. Selecione condicoes relevantes para que o Coach ajuste intensidade, alertas e limites de seguranca.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          AppPanel(
            color: palette.secondary.withValues(alpha: 0.06),
            borderColor: palette.secondary.withValues(alpha: 0.16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTag(label: 'COACH.AI', color: palette.secondary),
                const SizedBox(height: 12),
                Text(
                  'Vou avaliar suas informacoes para montar um programa seguro e personalizado. Se voce toma medicacao que altera frequencia cardiaca, ajusto as zonas de BPM automaticamente.',
                  style: context.runninType.bodySm.copyWith(
                    color: palette.text.withValues(alpha: 0.86),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...options.map(
                (option) => _ConditionChip(
                  label: option,
                  selected: selected.contains(option),
                  onTap: () => onToggle(option),
                ),
              ),
              ...customOptions.map(
                (option) => _ConditionChip(
                  label: option,
                  selected: true,
                  onTap: () => onToggle(option),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: otherController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAddOther(),
                  decoration: const InputDecoration(
                    hintText: 'Adicionar outra condicao ou medicacao',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 48,
                child: OutlinedButton(
                  onPressed: onAddOther,
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: Icon(Icons.add, color: palette.primary),
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
          _StepCode('ASSESSMENT_06'),
          const SizedBox(height: 12),
          Text('Qual sua meta principal?', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'O Coach monta periodização, volume e progressão com base no seu objetivo.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          ...goals.map((goal) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FigmaSelectionButton(
              label: goal,
              selected: selectedGoal == goal,
              onTap: () => onGoalSelect(goal),
            ),
          )),
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
      3: 'Constancia',
      4: 'Equilibrio',
      5: 'Performance',
      6: 'Alta carga',
    };
    final coachNotes = <int, String>{
      2: 'Otimo para comecar com constancia sem pesar a rotina. Vamos priorizar adaptacao e recuperacao.',
      3: 'Boa frequencia para criar base com seguranca. Ja da para evoluir volume e ritmo aos poucos.',
      4: 'Excelente equilibrio entre progresso e recuperacao. Costuma render planos bem completos.',
      5: 'Frequencia forte. O Coach vai distribuir carga com mais precisao para evitar excesso.',
      6: 'Rotina de alto compromisso. Vamos controlar intensidade para sustentar consistencia.',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepCode('ASSESSMENT_06'),
              const SizedBox(height: 12),
              Text(
                'Quantas vezes por semana?',
                style: context.runninType.displayMd,
              ),
              const SizedBox(height: 10),
              Text(
                'O Coach distribui estimulo e descanso com base nessa rotina.',
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
        _StepCode('ASSESSMENT_07'),
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
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
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

class _ConditionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return InkWell(
      onTap: onTap,
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
          style: context.runninType.bodySm.copyWith(
            color: selected ? palette.primary : palette.text,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
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
            'O Coach esta montando sua periodizacao\ncom base no seu perfil.',
            style: type.bodyMd.copyWith(color: palette.muted, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StepCode extends StatelessWidget {
  final String value;

  const _StepCode(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      '// $value',
      style: context.runninType.labelMd.copyWith(
        color: context.runninPalette.primary,
      ),
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
