import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_colors.dart';
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';

class PrepPage extends StatelessWidget {
  const PrepPage({super.key});

  @override
  Widget build(BuildContext context) => const _PrepView();
}

class _PrepView extends StatefulWidget {
  const _PrepView();

  @override
  State<_PrepView> createState() => _PrepViewState();
}

class _PrepViewState extends State<_PrepView> {
  final _types = [
    'Easy Run',
    'Intervalado',
    'Tempo Run',
    'Long Run',
    'Free Run',
  ];
  String _selectedType = 'Easy Run';

  static const _typeDetails = {
    'Easy Run': (
      'Rodagem leve para construir consistencia',
      'Ideal para dias de base, recuperacao ativa e ajuste tecnico sem subir demais a carga.',
      ['Ritmo solto', 'Respiracao controlada', 'Foco em economia'],
    ),
    'Intervalado': (
      'Blocos fortes com recuperacao entre tiros',
      'Boa opcao para velocidade e VO2. Vale chegar com aquecimento caprichado.',
      ['Tiros curtos', 'Recuperacao guiada', 'Alta intensidade'],
    ),
    'Tempo Run': (
      'Ritmo sustentado para limiar e consistencia',
      'Pede concentracao e estabilidade. O objetivo e correr forte sem quebrar no final.',
      ['Ritmo estavel', 'Esforco controlado', 'Mental firme'],
    ),
    'Long Run': (
      'Volume para resistencia e adaptacao',
      'Sessao boa para base aerobica. Hidratacao e paciencia fazem diferenca aqui.',
      ['Duracao maior', 'Pace conservador', 'Foco em resistencia'],
    ),
    'Free Run': (
      'Corrida livre para registrar o momento',
      'Quando quiser apenas sair para correr, o app acompanha sem travar voce num protocolo.',
      ['Sem meta fixa', 'Leitura livre', 'Bom para explorar'],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final detail = _typeDetails[_selectedType] ?? _typeDetails['Free Run']!;

    return BlocListener<RunBloc, RunState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.error != curr.error,
      listener: (context, state) {
        if (state.runId != null) {
          if (state.status == RunStatus.active) {
            context.pushReplacement('/run', extra: state.runId);
          }
        }

        if (state.status == RunStatus.error && state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('PREPARAR CORRIDA'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIPO DE TREINO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _types.map((t) {
                          final sel = _selectedType == t;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedType = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.accent
                                    : AppColors.surface,
                                border: Border.all(
                                  color: sel
                                      ? AppColors.accent
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                t.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                  color: sel
                                      ? AppColors.background
                                      : AppColors.muted,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.$1.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              detail.$2,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...detail.$3.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 5),
                                      child: Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BlocBuilder<RunBloc, RunState>(
                builder: (context, state) => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: state.status == RunStatus.starting
                        ? null
                        : () {
                            context.read<RunBloc>().add(
                              StartRun(type: _selectedType),
                            );
                          },
                    child: state.status == RunStatus.starting
                        ? const CircularProgressIndicator(
                            color: AppColors.background,
                            strokeWidth: 2,
                          )
                        : const Text('INICIAR CORRIDA'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
