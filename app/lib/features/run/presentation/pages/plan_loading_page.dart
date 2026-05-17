import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/shared/widgets/coach_ai_breadcrumb.dart';
import 'package:runnin/shared/widgets/plan_task_row.dart';

/// Etapa final do onboarding/pós-paywall: garante que o user tem um plano
/// gerado pela IA antes de cair em /home.
///
/// Fluxo:
///  1. Marca onboarding como concluído (cache + Firestore via /users/me).
///  2. Checa /plans/current — se já existe plano (não 'failed'), pula
///     animação e vai direto pra /home. Evita re-gerar em cache clear.
///  3. Se não existe, dispara POST /plans/generate (assíncrono no server) e
///     fica polling /plans/current até status 'ready' (ou fallback timeout).
///  4. Animação dos 8 passos só serve pra preencher o tempo da chamada.
class PlanLoadingPage extends StatefulWidget {
  const PlanLoadingPage({super.key});

  @override
  State<PlanLoadingPage> createState() => _PlanLoadingPageState();
}

class _PlanLoadingPageState extends State<PlanLoadingPage> {
  static const _taskEntries = [
    ('Analisando seu perfil e histórico de saúde...', 'Nível, idade, peso, condições'),
    ('Calculando zonas cardíacas personalizadas...', 'Z1-Z5 baseadas no seu perfil'),
    ('Definindo volume e progressão semanal...', 'Periodização linear 3:1'),
    ('Gerando plano do primeiro mesociclo...', '4 semanas adaptativas'),
    ('Calibrando alertas de segurança...', null),
    ('Definindo metas de XP e gamificação...', null),
    ('Preparando sua primeira sessão...', null),
    ('Plano pronto!', null),
  ];

  int _completedCount = 0;
  Timer? _timer;
  String? _error;
  final _userDs = UserRemoteDatasource();
  final _planDs = PlanRemoteDatasource();

  @override
  void initState() {
    super.initState();
    markOnboardingDone();
    _kickoff();
  }

  Future<void> _kickoff() async {
    try {
      // Plano já existe? Pula animação inteira.
      final existing = await _planDs.getCurrentPlan();
      if (existing != null) {
        if (mounted) context.go('/home');
        return;
      }

      // Dispara generate (server vai criar status='generating' e processa async)
      final profile = await _userDs.getMe();
      if (profile == null) {
        if (mounted) context.go('/home');
        return;
      }
      await _planDs.generatePlan(
        goal: profile.goal,
        level: profile.level,
        frequency: profile.frequency,
      );

      // Roda animação enquanto faz polling de /plans/current
      _timer = Timer.periodic(const Duration(milliseconds: 800), _tick);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
      // Mesmo em erro vai pra /home — user pode gerar manualmente em training
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/home');
      });
    }
  }

  Future<void> _tick(Timer timer) async {
    if (_completedCount < _taskEntries.length) {
      setState(() => _completedCount++);
    }
    // A cada tick checa se o plano ficou pronto
    try {
      final plan = await _planDs.getCurrentPlan();
      final ready = plan != null && plan.isReady;
      if (ready || _completedCount >= _taskEntries.length) {
        timer.cancel();
        if (mounted) context.go('/home');
      }
    } catch (_) {
      // Ignora erros temporários de network — segue animação
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CoachAIBreadcrumb(action: 'GERANDO PLANO'),
              const SizedBox(height: 24),
              const Text(
                'Criando seu plano',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.48,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Analisando perfil para criar seu plano',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1.5,
                  color: _error != null
                      ? const Color(0xFFFF6B35)
                      : const Color(0x8CFFFFFF),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _taskEntries.length; i++)
                        PlanTaskRow(
                          status: i < _completedCount
                              ? PlanTaskStatus.done
                              : i == _completedCount
                                  ? PlanTaskStatus.active
                                  : PlanTaskStatus.pending,
                          label: i < _completedCount
                              ? 'OK'
                              : i == _completedCount
                                  ? '●'
                                  : '○',
                          mainText: _taskEntries[i].$1,
                          detail: _taskEntries[i].$2,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
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
                        width: constraints.maxWidth *
                            (_completedCount / _taskEntries.length),
                        height: 4,
                        color: FigmaColors.brandCyan,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
