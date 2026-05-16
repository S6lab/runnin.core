import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
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

  static const _totalSteps = 13;
  static const _loginStep = 3;
  static const _firstAssessmentStep = 4;

  int _step = 0;
  String _level = 'iniciante';
  String _goal = 'Completar 10K';
  int _frequency = 4;
  String? _pace;
  String? _runPeriod;
  String? _wakeTime;
  String? _sleepTime;
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

  static const _paceOptions = [
    'Não sei o que é pace',
    'Acima de 7:00/km',
    'Entre 6:00 e 7:00/km',
    'Entre 5:00 e 6:00/km',
    'Abaixo de 5:00/km',
    'Deixa o Coach decidir',
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
      _error = null;
      _submitting = true;
    });
    _doSubmit();
    if (mounted) context.push('/plan-loading');
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
        targetPace: _pace,
        hasWearable: _hasWearable,
        medicalConditions: _medicalConditions.toList()..sort(),
      );
      markOnboardingDone();
    } catch (_) {
      // User already navigated to PlanLoadingPage; silent best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          FigmaOnboardingTopProgressBar(total: _totalSteps, currentIndex: _step),
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
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragEnd: _handleSwipe,
                        child: _buildStep(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildNav(context),
                    const SizedBox(height: 12),
                    FigmaOnboardingPageIndicator(total: _totalSteps, currentIndex: _step),
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
        return _StepPace(
          selected: _pace,
          options: _paceOptions,
          onSelect: (value) => setState(() => _pace = value),
        );
      case 11:
        return _StepRoutine(
          selectedPeriod: _runPeriod,
          selectedWakeTime: _wakeTime,
          selectedSleepTime: _sleepTime,
          onPeriodSelect: (v) => setState(() => _runPeriod = v),
          onWakeTimeSelect: (v) => setState(() => _wakeTime = v),
          onSleepTimeSelect: (v) => setState(() => _sleepTime = v),
        );
      case 12:
        return _StepWearableV2(
          selected: _hasWearable,
          onSelect: (value) => setState(() => _hasWearable = value),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNav(BuildContext context) {
    final palette = context.runninPalette;
    final isLastDataStep = _step == _totalSteps - 1;
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

  void _handleSwipe(DragEndDetails details) {
    if (_authLoading || _submitting) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 300 && _step > 0) {
      setState(() => _step--);
    } else if (velocity < -300 &&
        _step != _loginStep &&
        _step < _totalSteps - 1 &&
        _canProceed()) {
      _nextStep();
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
          const FigmaFormFieldLabel(text: 'TELEFONE'),
          const SizedBox(height: 8),
          FigmaFormTextField(
            controller: phoneController,
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
            controller: smsCodeController,
            enabled: codeRequested,
          ),
          if (codeRequested) ...[
            const SizedBox(height: 8),
            OtpResendButton(
              controller: resendController,
              onResend: onResendCode,
            ),
          ],
          const SizedBox(height: 18),
          FigmaGoogleSignInButton(
            onPressed: loading ? null : onGoogleSignIn,
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

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      birthDateController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaAssessmentLabel(text: 'ASSESSMENT_02'),
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Como te chamo?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'Nome e data de nascimento ajudam o Coach a personalizar comunicacao, zonas e progressao.',
          ),
          const SizedBox(height: 28),
          const FigmaFormFieldLabel(text: 'SEU NOME'),
          const SizedBox(height: 8),
          FigmaFormTextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            height: 51.5,
            placeholder: 'Ex: Lucas',
          ),
          const SizedBox(height: 28),
          const FigmaFormFieldLabel(text: 'DATA DE NASCIMENTO'),
          const SizedBox(height: 8),
          FigmaFormTextField(
            controller: birthDateController,
            height: 51.5,
            readOnly: true,
            onTap: () => _pickDate(context),
            placeholder: 'dd/mm/aaaa',
          ),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FigmaAssessmentLabel(text: 'ASSESSMENT_01'),
        const SizedBox(height: 12),
        const FigmaAssessmentHeading(text: 'Qual seu nivel atual?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text: 'O Coach adapta intensidade, volume e progressao ao seu nivel.',
        ),
        const SizedBox(height: 32),
        ...levels.map((level) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FigmaSelectionButton(
              label: '${level.$2} - ${level.$3}',
              selected: selected == level.$1,
              onTap: () => onSelect(level.$1),
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaAssessmentLabel(text: 'ASSESSMENT_03'),
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Peso e altura'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'Usamos isso para estimar gasto calorico, zonas e carga de impacto.',
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: FigmaNumericInputField(
                  label: 'PESO',
                  unit: 'kg',
                  controller: weightController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FigmaNumericInputField(
                  label: 'ALTURA',
                  unit: 'cm',
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
          Text('Informações de saúde', style: context.runninType.displayMd),
          const SizedBox(height: 10),
          Text(
            'Opcional, mas importante. Selecione condições relevantes para que o Coach ajuste intensidade, alertas e limites de segurança.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          FigmaCoachAIBlock(
            variant: CoachAIBlockVariant.assessment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FigmaCoachAIBreadcrumb(action: 'ANÁLISE'),
                const SizedBox(height: 12),
                Text(
                  'Vou avaliar todas as suas informações para montar um programa de treino seguro e personalizado. Se você toma medicação que altera frequência cardíaca, por exemplo, ajusto as zonas de BPM automaticamente.',
                  style: context.runninType.bodySm.copyWith(
                    color: palette.text.withValues(alpha: 0.70),
                    height: 21.45 / 13,
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
                (option) => FigmaHealthChip(
                  label: option,
                  selected: selected.contains(option),
                  onTap: () => onToggle(option),
                ),
              ),
              ...customOptions.map(
                (option) => FigmaHealthChip(
                  label: option,
                  selected: true,
                  onTap: () => onToggle(option),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DashedAddButton(
            label: '+ Adicionar outra condição ou medicação',
            controller: otherController,
            onAdd: onAddOther,
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaAssessmentLabel(text: '// ASSESSMENT_06'),
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Qual sua meta principal?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'O Coach monta periodização, volume e progressão com base no seu objetivo.',
          ),
          const SizedBox(height: 24),
          ...goals.map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FigmaSelectionButton(
                label: goal,
                selected: selectedGoal == goal,
                onTap: () => onGoalSelect(goal),
              ),
            ),
          ),
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
    const options = <int, String>{
      2: '2x',
      3: '3x',
      4: '4x',
      5: '5x',
      6: '6x+',
    };
    final coachNotes = <int, String>{
      2: 'Otimo para comecar com constancia sem pesar a rotina. Vamos priorizar adaptacao e recuperacao.',
      3: 'Boa frequencia para criar base com seguranca. Ja da para evoluir volume e ritmo aos poucos.',
      4: 'Excelente equilibrio entre progresso e recuperacao. Costuma render planos bem completos.',
      5: 'Frequencia forte. O Coach vai distribuir carga com mais precisao para evitar excesso.',
      6: 'Rotina de alto compromisso. Vamos controlar intensidade para sustentar consistencia.',
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaAssessmentLabel(text: '// ASSESSMENT_05'),
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Quantas vezes por semana?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'O Coach distribui sessões com descanso adequado entre cada corrida.',
          ),
          const SizedBox(height: 24),
          ...options.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FigmaSelectionButton(
                label: e.value,
                selected: frequency == e.key,
                onTap: () => onFreqChange(e.key),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FigmaCoachAIBlock(
            variant: CoachAIBlockVariant.assessment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FigmaCoachAIBreadcrumb(action: 'NOTA'),
                const SizedBox(height: 12),
                FigmaAssessmentDescription(text: coachNotes[frequency]!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPace extends StatelessWidget {
  final String? selected;
  final List<String> options;
  final ValueChanged<String> onSelect;

  const _StepPace({
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FigmaAssessmentLabel(text: '// ASSESSMENT_07'),
        const SizedBox(height: 12),
        const FigmaAssessmentHeading(text: 'Você tem um pace alvo?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text:
              'Não se preocupe se não sabe — o Coach avalia na primeira corrida e calibra tudo automaticamente.',
        ),
        const SizedBox(height: 24),
        ...options.map((option) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FigmaSelectionButton(
              label: option,
              selected: selected == option,
              onTap: () => onSelect(option),
            ),
          );
        }),
      ],
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
        _StepCode('ASSESSMENT_08'),
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

class _DashedAddButton extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _DashedAddButton({
    required this.label,
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.text.trim().isNotEmpty) {
          onAdd();
        }
      },
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: FigmaColors.borderDefault,
          strokeWidth: FigmaDimensions.borderUniversal,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54.5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.brandCyan,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Adicionar outra condição ou medicação',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedBorderPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}

class _StepRoutine extends StatelessWidget {
  final String? selectedPeriod;
  final String? selectedWakeTime;
  final String? selectedSleepTime;
  final ValueChanged<String> onPeriodSelect;
  final ValueChanged<String> onWakeTimeSelect;
  final ValueChanged<String> onSleepTimeSelect;

  const _StepRoutine({
    required this.selectedPeriod,
    required this.selectedWakeTime,
    required this.selectedSleepTime,
    required this.onPeriodSelect,
    required this.onWakeTimeSelect,
    required this.onSleepTimeSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaAssessmentLabel(text: '// ASSESSMENT_08'),
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Rotina e horário'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'O Coach usa seu horário para calcular janela metabólica ideal, lembretes de hidratação, preparo nutricional e sugestão de melhor hora para correr.',
          ),
          const SizedBox(height: 24),
          Text(
            'QUANDO PREFERE CORRER?',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.65,
              color: FigmaColors.brandCyan,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FigmaTimePeriodCard(
                icon: Icons.wb_sunny_outlined,
                label: 'Manhã',
                hours: '06-09h',
                hint: 'Cortisol alto,\nqueima de gordura',
                selected: selectedPeriod == 'manha',
                onTap: () => onPeriodSelect('manha'),
              ),
              const SizedBox(width: 8),
              FigmaTimePeriodCard(
                icon: Icons.wb_twilight,
                label: 'Tarde',
                hours: '14-17h',
                hint: 'Pico de temperatura\ncorporal',
                selected: selectedPeriod == 'tarde',
                onTap: () => onPeriodSelect('tarde'),
              ),
              const SizedBox(width: 8),
              FigmaTimePeriodCard(
                icon: Icons.nightlight_outlined,
                label: 'Noite',
                hours: '19-21h',
                hint: 'Força muscular\nelevada',
                selected: selectedPeriod == 'noite',
                onTap: () => onPeriodSelect('noite'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACORDA',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.65,
                        color: FigmaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...['05:00', '06:00', '07:00', '08:00'].map(
                      (time) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _TimeOptionButton(
                          label: time,
                          selected: selectedWakeTime == time,
                          onTap: () => onWakeTimeSelect(time),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DORME',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.65,
                        color: FigmaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...['21:00', '22:00', '23:00', '00:00'].map(
                      (time) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _TimeOptionButton(
                          label: time,
                          selected: selectedSleepTime == time,
                          onTap: () => onSleepTimeSelect(time),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeOptionButton({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 44.5,
        decoration: BoxDecoration(
          color: selected
              ? FigmaColors.selectionActiveBg
              : FigmaColors.surfaceCard,
          border: Border.all(
            color: selected
                ? FigmaColors.selectionActiveBorder
                : FigmaColors.borderDefault,
            width: FigmaDimensions.borderUniversal,
          ),
          borderRadius: FigmaBorderRadius.zero,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: selected
                ? FigmaColors.textPrimary
                : FigmaColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StepWearableV2 extends StatelessWidget {
  final bool selected;
  final ValueChanged<bool> onSelect;

  const _StepWearableV2({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FigmaAssessmentLabel(text: '// ASSESSMENT_09'),
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Conectar wearable?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'Dados de BPM, sono e atividade permitem que o Coach personalize com mais precisão.',
          ),
          const SizedBox(height: 24),
          FigmaSelectionButton(
            label: 'Sim (recomendado)',
            selected: selected == true,
            onTap: () => onSelect(true),
          ),
          const SizedBox(height: 8),
          FigmaSelectionButton(
            label: 'Depois',
            selected: selected == false,
            onTap: () => onSelect(false),
          ),
          const SizedBox(height: 24),
          FigmaCoachAIBlock(
            variant: CoachAIBlockVariant.assessment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: FigmaColors.brandOrange.withValues(alpha: 0.50),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '> COACH.AI',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.65,
                        color: FigmaColors.brandOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tenho tudo que preciso — incluindo sua rotina de sono e horário preferido. Vou calcular a janela metabólica ideal para cada tipo de treino, enviar lembretes de hidratação e preparo nutricional, e sugerir o melhor horário com base no seu padrão de sono.',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 23.1 / 14,
                    color: const Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FigmaCyanInfoBlock(
            icon: Icons.description_outlined,
            title: 'Tem exames médicos recentes?',
            bodyWidget: Text.rich(
              TextSpan(
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 19.2 / 12,
                  color: FigmaColors.textSecondary,
                ),
                children: [
                  const TextSpan(
                    text:
                        'Testes ergométricos, exames de sangue e laudos médicos permitem que eu calibre zonas cardíacas com FC máx real, monitore ferritina e identifique restrições. Após criar seu plano, acesse ',
                  ),
                  TextSpan(
                    text: 'Perfil → Saúde → Exames',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 19.2 / 12,
                      color: FigmaColors.brandCyan,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' para enviar até 5 arquivos por mês (PDF ou foto, máx 10MB).',
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
