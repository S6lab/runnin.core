import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/coach_ai_breadcrumb.dart';
import 'package:runnin/shared/widgets/plan_task_row.dart';

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
  late final Timer _timer;
  final _ds = UserRemoteDatasource();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 750), _tick);
  }

  Future<void> _tick(Timer timer) async {
    if (_completedCount >= _taskEntries.length) {
      timer.cancel();
      markOnboardingDone();
      if (!mounted) return;
      // Route Coach Intro on first plan (intro only on first time)
      bool introSeen = false;
      try {
        final profile = await _ds.getMe();
        introSeen = profile?.coachIntroSeen ?? false;
      } catch (_) {
        introSeen = false;
      }
      if (!mounted) return;
      context.go(introSeen ? '/home' : '/coach-intro');
      return;
    }
    setState(() => _completedCount++);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: Center(
        child: SizedBox(
          width: 329.55,
          height: 613.716,
          child: Column(
            children: [
              const SizedBox(height: 118.901),
              const CoachAIBreadcrumb(action: 'GERANDO PLANO'),
              const SizedBox(height: 37.98),
              const Text(
                'Criando seu plano',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.48,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 34.37),
              const Text(
                'Analisando perfil para criar seu plano',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1.5,
                  color: Color(0x8CFFFFFF),
                ),
              ),
              const SizedBox(height: 51.51),
              for (var i = 0; i < _taskEntries.length; i++)
                PlanTaskRow(
                  status: i < _completedCount
                      ? PlanTaskStatus.done
                      : i == _completedCount
                          ? PlanTaskStatus.active
                          : PlanTaskStatus.pending,
                  label: i < _completedCount ? 'OK' : i == _completedCount ? '●' : '○',
                  mainText: _taskEntries[i].$1,
                  detail: _taskEntries[i].$2,
                ),
              const Spacer(),
              SizedBox(
                width: 329.55,
                height: 4,
                child: Stack(
                  children: [
                    const SizedBox.expand(
                      child: ColoredBox(color: FigmaColors.borderDefault),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      width: 329.55 * (_completedCount / _taskEntries.length),
                      height: 4,
                      color: FigmaColors.brandCyan,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3.284),
            ],
          ),
        ),
      ),
    );
  }
}
