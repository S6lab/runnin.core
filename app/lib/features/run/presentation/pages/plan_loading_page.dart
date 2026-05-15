import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/coach_ai_breadcrumb.dart';
import 'package:runnin/shared/widgets/plan_task_row.dart';

class PlanLoadingPage extends StatefulWidget {
  const PlanLoadingPage({super.key});

  @override
  State<PlanLoadingPage> createState() => _PlanLoadingPageState();
}

class _PlanLoadingPageState extends State<PlanLoadingPage> {
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
                'Analisando nível , objetivo: 10K',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1.5,
                  color: Color(0x8CFFFFFF),
                ),
              ),
              const SizedBox(height: 51.51),
              ..._getTasks().map((task) {
                return PlanTaskRow(
                  status: task.status,
                  label: task.label,
                  mainText: task.mainText,
                  detail: task.detail,
                );
              }),
              const Spacer(),
              const SizedBox(width: 329.55, height: 4),
              const SizedBox(height: 3.284),
            ],
          ),
        ),
      ),
    );
  }

  List<_TaskData> _getTasks() {
    return [
      _TaskData(
        status: PlanTaskStatus.done,
        label: 'OK',
        mainText: 'Analisando seu perfil e histórico de saúde...',
        detail: 'Nível, idade, peso, condições',
      ),
      _TaskData(
        status: PlanTaskStatus.done,
        label: 'OK',
        mainText: 'Calculando zonas cardíacas personalizadas...',
        detail: 'Z1-Z5 baseadas no seu perfil',
      ),
      _TaskData(
        status: PlanTaskStatus.done,
        label: 'OK',
        mainText: 'Definindo volume e progressão semanal...',
        detail: 'Periodização linear 3:1',
      ),
      _TaskData(
        status: PlanTaskStatus.active,
        label: '●',
        mainText: 'Gerando plano do primeiro mesociclo...',
        detail: '4 semanas adaptativas',
      ),
      _TaskData(
        status: PlanTaskStatus.pending,
        label: '○',
        mainText: 'Calibrando alertas de segurança...',
        detail: null,
      ),
      _TaskData(
        status: PlanTaskStatus.pending,
        label: '○',
        mainText: 'Definindo metas de XP e gamificação...',
        detail: null,
      ),
      _TaskData(
        status: PlanTaskStatus.pending,
        label: '○',
        mainText: 'Preparando sua primeira sessão...',
        detail: null,
      ),
      _TaskData(
        status: PlanTaskStatus.pending,
        label: '○',
        mainText: 'Plano pronto!',
        detail: null,
      ),
    ];
  }
}

class _TaskData {
  final PlanTaskStatus status;
  final String label;
  final String mainText;
  final String? detail;

  const _TaskData({
    required this.status,
    required this.label,
    required this.mainText,
    this.detail,
  });
}
