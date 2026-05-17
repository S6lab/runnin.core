import 'dart:async';

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
/// Fluxo:
///  1. Se plano já existe → /home.
///  2. Senão dispara POST /plans/generate (server processa async).
///  3. Polling a cada 3s. Quando ready → /home.
///  4. Após 30s mostra "+X segundos · análise criteriosa demora".
///  5. Após 90s mostra botão "IR PRA HOME (plano segue gerando em background)".
///  6. Ícone TREINO (directions_run) animado deslizando horizontalmente
///     como se estivesse correndo.
class PlanLoadingPage extends StatefulWidget {
  final String? startDate;
  const PlanLoadingPage({super.key, this.startDate});

  @override
  State<PlanLoadingPage> createState() => _PlanLoadingPageState();
}

class _PlanLoadingPageState extends State<PlanLoadingPage>
    with TickerProviderStateMixin {
  static const _expectedSeconds = 30;
  static const _showSkipAfter = 90;

  Timer? _pollTimer;
  Timer? _tickTimer;
  int _elapsedSeconds = 0;
  bool _planReady = false;
  String? _error;
  final _userDs = UserRemoteDatasource();
  final _planDs = PlanRemoteDatasource();

  late final AnimationController _runAnim;

  @override
  void initState() {
    super.initState();
    markOnboardingDone();
    _runAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _kickoff();
  }

  Future<void> _kickoff() async {
    try {
      final existing = await _planDs.getCurrentPlan();
      if (existing != null && existing.isReady) {
        if (mounted) context.go('/home');
        return;
      }

      // Só dispara generate se NÃO existe plano. Se já está 'generating'
      // só fica polling.
      if (existing == null) {
        final profile = await _userDs.getMe();
        if (profile == null) {
          if (mounted) context.go('/home');
          return;
        }
        await _planDs.generatePlan(
          goal: profile.goal,
          level: profile.level,
          frequency: profile.frequency,
          startDate: widget.startDate,
        );
      }

      _pollTimer = Timer.periodic(const Duration(seconds: 3), _poll);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _poll(Timer t) async {
    try {
      final plan = await _planDs.getCurrentPlan();
      if (plan != null && plan.isReady) {
        t.cancel();
        if (mounted) {
          setState(() => _planReady = true);
        }
        // pequeno atraso pra user ver a confirmação
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) context.go('/home');
      } else if (plan != null && plan.status == 'failed') {
        t.cancel();
        if (mounted) {
          setState(() => _error =
              'Falha ao gerar plano. Tente novamente em TREINO > GERAR PLANO.');
        }
      }
    } catch (_) {
      // tolera erros de network — segue polling
    }
  }

  void _skipToHome() {
    _pollTimer?.cancel();
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _runAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_expectedSeconds - _elapsedSeconds).clamp(0, _expectedSeconds);
    final overtime = _elapsedSeconds > _expectedSeconds;
    final canSkip = _elapsedSeconds >= _showSkipAfter;

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CoachAIBreadcrumb(action: 'GERANDO PLANO'),
              const SizedBox(height: 32),

              // Runner animado
              _RunnerAnimation(animation: _runAnim),

              const SizedBox(height: 40),

              Text(
                _planReady ? 'Plano pronto.' : 'Criando seu plano',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.4,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

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
              else if (_planReady)
                Text(
                  'Mesociclo de ${widget.startDate != null ? "" : ""}semanas pronto. Levando você pra TREINO.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overtime
                          ? 'Análise criteriosa de TODOS os seus dados (perfil + condições + objetivo + horários). Demora porque é personalizado.'
                          : 'Lendo seu perfil, condições médicas, objetivo e horários. Calculando zonas e progressão.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Countdown / contador
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          overtime ? '+${_elapsedSeconds - _expectedSeconds}s' : '${remaining}s',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 56,
                            fontWeight: FontWeight.w500,
                            color: overtime
                                ? FigmaColors.brandCyan
                                : Colors.white,
                            letterSpacing: -1.2,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            overtime ? 'além do estimado' : 'estimado',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              const Spacer(),

              // Progress bar visual
              if (!_planReady && _error == null) ...[
                _LinearProgress(
                  fraction: (_elapsedSeconds / _expectedSeconds).clamp(0, 1),
                  isOvertime: overtime,
                ),
                const SizedBox(height: 16),
              ],

              if (canSkip && !_planReady && _error == null)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _skipToHome,
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
                      'IR PRA HOME · plano gera em background',
                      style: TextStyle(
                        color: FigmaColors.brandCyan,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _skipToHome,
                    child: const Text('IR PRA HOME'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícone de TREINO (directions_run) animado deslizando horizontalmente
/// como se estivesse correndo em loop. Sem dependências extras.
class _RunnerAnimation extends StatelessWidget {
  final Animation<double> animation;
  const _RunnerAnimation({required this.animation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          // Desloca horizontalmente em loop: -1 → +1 → reset
          final t = animation.value;
          // Pulsar de pulso (bobble pra cima/baixo enquanto corre)
          final bob = (1 - (2 * t - 1).abs()) * 4; // pico no meio
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GroundPainter(progress: t),
                ),
              ),
              Positioned(
                left: 20 + t * 80,
                top: 18 - bob,
                child: Transform.rotate(
                  angle: -0.05,
                  child: Icon(
                    Icons.directions_run,
                    size: 56,
                    color: FigmaColors.brandCyan,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroundPainter extends CustomPainter {
  final double progress;
  _GroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FigmaColors.borderDefault.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    // Linha do chão
    canvas.drawLine(
      Offset(0, size.height - 8),
      Offset(size.width, size.height - 8),
      paint,
    );
    // Tracinhos passando (dão sensação de movimento)
    final tickPaint = Paint()
      ..color = FigmaColors.brandCyan.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    final offset = (progress * 40) % 40;
    for (double x = -offset; x < size.width; x += 40) {
      canvas.drawLine(
        Offset(x, size.height - 4),
        Offset(x + 14, size.height - 4),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _LinearProgress extends StatelessWidget {
  final double fraction;
  final bool isOvertime;
  const _LinearProgress({required this.fraction, required this.isOvertime});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 4,
      child: Stack(
        children: [
          const SizedBox.expand(
            child: ColoredBox(color: FigmaColors.borderDefault),
          ),
          LayoutBuilder(
            builder: (context, constraints) => AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              width: constraints.maxWidth * fraction,
              height: 4,
              color: isOvertime
                  ? FigmaColors.brandCyan.withValues(alpha: 0.6)
                  : FigmaColors.brandCyan,
            ),
          ),
        ],
      ),
    );
  }
}
