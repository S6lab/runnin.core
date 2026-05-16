import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_body.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_frequency.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_gender.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_goal.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_identity.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_intro.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_level.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_login.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_medical.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_pace.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_routine.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_step_wearable.dart';
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

  static const _totalSteps = 14; // 3 intro + login + 10 assessment (incl. gender)
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
  String? _gender; // 'male' | 'female' | 'other' | 'na'
  bool _hasWearable = false;
  bool _authLoading = false;
  bool _submitting = false;
  String? _phoneVerificationId;
  int? _phoneResendToken;
  ConfirmationResult? _phoneConfirmationResult;
  String? _error;
  String? _message;
  final _resendCtrl = OtpResendController();

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
    if (!mounted) return;
    // Gate freemium: anônimo ou não-premium vai pro paywall.
    // Se assinar (ou continuar grátis), próximo destino é /home (sem plano AI).
    // Premium real → plan-loading e geração do plano.
    final user = FirebaseAuth.instance.currentUser;
    final isAnon = user?.isAnonymous ?? false;
    final profile = await _ds.getMe().catchError((_) => null);
    final premium = profile?.premium ?? false;
    if (!mounted) return;
    if (isAnon || !premium) {
      context.go('/paywall?next=/home');
    } else {
      context.push('/plan-loading');
    }
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
        gender: _gender,
        runPeriod: _runPeriod,
        wakeTime: _wakeTime,
        sleepTime: _sleepTime,
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
        return OnboardingStepIntro(slide: kOnboardingIntroSlides[_step]);
      case _loginStep:
        return OnboardingStepLogin(
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
        return OnboardingStepLevel(
          selected: _level,
          onSelect: (value) => setState(() => _level = value),
        );
      case 5:
        return OnboardingStepIdentity(
          nameController: _nameCtrl,
          birthDateController: _birthDateCtrl,
        );
      case 6:
        return OnboardingStepGender(
          selected: _gender,
          onSelect: (value) => setState(() => _gender = value),
        );
      case 7:
        return OnboardingStepBody(
          weightController: _weightCtrl,
          heightController: _heightCtrl,
        );
      case 8:
        return OnboardingStepMedical(
          selected: _medicalConditions,
          otherController: _medicalOtherCtrl,
          onToggle: _toggleMedicalCondition,
          onAddOther: _addOtherMedicalCondition,
        );
      case 9:
        return OnboardingStepGoal(
          selectedGoal: _goal,
          onGoalSelect: (value) => setState(() => _goal = value),
        );
      case 10:
        return OnboardingStepFrequency(
          frequency: _frequency,
          onFreqChange: (value) => setState(() => _frequency = value),
        );
      case 11:
        return OnboardingStepPace(
          selected: _pace,
          onSelect: (value) => setState(() => _pace = value),
        );
      case 12:
        return OnboardingStepRoutine(
          selectedPeriod: _runPeriod,
          selectedWakeTime: _wakeTime,
          selectedSleepTime: _sleepTime,
          onPeriodSelect: (v) => setState(() => _runPeriod = v),
          onWakeTimeSelect: (v) => setState(() => _wakeTime = v),
          onSleepTimeSelect: (v) => setState(() => _sleepTime = v),
        );
      case 13:
        return OnboardingStepWearable(
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
        if (_step == 8)
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
        return _gender != null;
      case 7:
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
