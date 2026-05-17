import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/shared/widgets/coach_ai_breadcrumb.dart';

/// Tela "Criando seu plano" pós-onboarding.
///
/// Estratégia:
///  - dispara POST /plans/generate em background (fire-and-forget)
///  - relógio com countdown de 15s (apenas wait visual — o plano
///    continua sendo gerado pelo coach AI no servidor)
///  - mensagem explica: "primeira geração leva ~60s porque o coach
///    está analisando perfil + objetivo + condições"
///  - após 15s → /home (não bloqueia o user). Polling na /training
///    detecta status='ready' e mostra o plano automaticamente.
///
/// Não temos fallback determinístico — plano só faz sentido com IA.
/// Se gerar falha, /training mostra status='failed' com botão de retry.
class PlanLoadingPage extends StatefulWidget {
  final String? startDate;
  const PlanLoadingPage({super.key, this.startDate});

  @override
  State<PlanLoadingPage> createState() => _PlanLoadingPageState();
}

class _PlanLoadingPageState extends State<PlanLoadingPage>
    with TickerProviderStateMixin {
  // 15s de "espera visual" no app + plano segue gerando em background
  // no server (60-90s normais pra IA). Polling na /training pega o
  // resultado quando ready. Aumentado de 10s pra dar tempo do user ler
  // a mensagem com calma antes de ir pra home.
  static const _countdownSeconds = 15;

  Timer? _tickTimer;
  int _elapsedSeconds = 0;
  bool _redirected = false;
  String? _error;
  final _userDs = UserRemoteDatasource();
  final _planDs = PlanRemoteDatasource();

  late final AnimationController _clockAnim;

  @override
  void initState() {
    super.initState();
    markOnboardingDone();
    _clockAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    )..forward();

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _countdownSeconds && !_redirected) {
        _redirected = true;
        context.go('/home');
      }
    });

    _kickoff();
  }

  /// Fire-and-forget: dispara generate no server (que processa async) e
  /// não bloqueia a UI esperando o resultado. Erros 409 (plano já existe)
  /// são silenciados — é race condition normal.
  Future<void> _kickoff() async {
    try {
      final existing = await _planDs.getCurrentPlan();
      if (existing != null) return; // já tem plano (ready ou generating)

      final profile = await _userDs.getMe();
      if (profile == null) return;

      try {
        await _planDs.generatePlan(
          goal: profile.goal,
          level: profile.level,
          frequency: profile.frequency,
          startDate: widget.startDate,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode != 409) rethrow;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Não consegui iniciar geração. Tenta de novo em TREINO > GERAR PLANO.');
      }
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _clockAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        (_countdownSeconds - _elapsedSeconds).clamp(0, _countdownSeconds);

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CoachAIBreadcrumb(action: 'GERANDO PLANO'),
              const SizedBox(height: 40),

              Center(
                child: _ClockCountdown(
                  animation: _clockAnim,
                  remaining: remaining,
                ),
              ),

              const SizedBox(height: 40),

              Text(
                'Montando seu plano',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.4,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
                    border: Border.all(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                )
              else ...[
                Text(
                  'A primeira geração leva entre 30 e 60 segundos. '
                  'O coach AI está cruzando seu perfil, objetivo, '
                  'condições e horários pra montar um plano único '
                  'pra você — não é um template.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 14),
                _AnalysisSteps(elapsedSeconds: _elapsedSeconds),
                const SizedBox(height: 14),
                Text(
                  'Você pode ir pra HOME — quando o plano ficar pronto, aparece automaticamente em TREINO.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    if (_redirected) return;
                    _redirected = true;
                    context.go('/home');
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: FigmaColors.brandCyan.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'IR PRA HOME AGORA',
                    style: TextStyle(
                      color: FigmaColors.brandCyan,
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Relógio com arco de countdown e segundo restante centralizado.
/// Segue o design system (mono, cyan brand, sem cantos arredondados além
/// do círculo natural).
/// Lista visual de "passos da análise" que o coach AI tá fazendo
/// enquanto user espera. Avança em cascata baseado em segundos
/// decorridos — propósito é dar feedback de progresso (não é o estado
/// real do server, é uma sequência fixa que cobre o tempo típico de
/// 30-60s do LLM).
class _AnalysisSteps extends StatelessWidget {
  final int elapsedSeconds;
  const _AnalysisSteps({required this.elapsedSeconds});

  static const _steps = [
    (label: 'Lendo seu perfil', threshold: 0),
    (label: 'Calculando zonas de FC e pace', threshold: 3),
    (label: 'Montando periodização do mesociclo', threshold: 7),
    (label: 'Criando roteiro km-a-km', threshold: 11),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in _steps)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _StepRow(
              label: s.label,
              done: elapsedSeconds >= s.threshold + 3,
              active: elapsedSeconds >= s.threshold &&
                  elapsedSeconds < s.threshold + 3,
            ),
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;
  const _StepRow({required this.label, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = done
        ? FigmaColors.brandCyan
        : active
            ? FigmaColors.brandCyan.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.35);
    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: done
              ? Icon(Icons.check, size: 14, color: color)
              : active
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 1.5,
                      ),
                    )
                  : Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                    ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: color,
            fontWeight: done || active ? FontWeight.w500 : FontWeight.w400,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _ClockCountdown extends StatelessWidget {
  final Animation<double> animation;
  final int remaining;
  const _ClockCountdown({required this.animation, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return CustomPaint(
            painter: _ClockPainter(progress: animation.value),
            child: Center(
              child: Text(
                '$remaining',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 56,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: -1.4,
                  height: 1.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final double progress; // 0 → 1
  _ClockPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;

    final track = Paint()
      ..color = FigmaColors.borderDefault
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = FigmaColors.brandCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final sweep = -2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );

    // Ponteiro: linha do centro até o ponto na borda
    final angle = -math.pi / 2 + sweep;
    final tip = Offset(
      center.dx + radius * 0.78 * math.cos(angle),
      center.dy + radius * 0.78 * math.sin(angle),
    );
    final handPaint = Paint()
      ..color = FigmaColors.brandCyan.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, handPaint);

    final hub = Paint()..color = FigmaColors.brandCyan;
    canvas.drawCircle(center, 3.5, hub);
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
