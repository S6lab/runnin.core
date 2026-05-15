import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/features/steps/domain/entities/step.dart';
import 'package:runnin/features/steps/presentation/bloc/step_bloc.dart' as steps_bloc;
import 'package:runnin/features/steps/presentation/widgets/step_card.dart';
import 'package:runnin/features/steps/presentation/widgets/step_navigation_buttons.dart';
import 'package:runnin/features/steps/presentation/widgets/step_progress_indicator.dart';
import 'package:runnin/core/theme/app_palette.dart';

class StepsPage extends StatelessWidget {
  final String flowId;
  final List<AppStep> steps;

  const StepsPage({
    super.key,
    required this.flowId,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => steps_bloc.StepBloc()..add(steps_bloc.StepInitialized(steps: steps)),
      child: const _StepsView(),
    );
  }
}

class _StepsView extends StatefulWidget {
  const _StepsView();

  @override
  State<_StepsView> createState() => _StepsViewState();
}

class _StepsViewState extends State<_StepsView> {
  late steps_bloc.StepBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<steps_bloc.StepBloc>();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<steps_bloc.StepBloc>().state;

    return BlocListener<steps_bloc.StepBloc, steps_bloc.StepState>(
      listener: (context, state) {
        if (state.stepsState.isCompleted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            context.go('/home');
          });
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                           state.errorMessage!,
                           style: context.runninType.bodySm.copyWith(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: StepProgressIndicator(
                currentStep: state.stepsState.currentIndex,
                totalSteps: state.stepsState.steps.length,
                stepLabel: 'PASSO ${state.stepsState.currentIndex + 1} DE ${state.stepsState.steps.isEmpty ? 0 : state.stepsState.steps.length}',
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.stepsState.steps.length,
                itemBuilder: (context, index) {
                  final step = state.stepsState.steps[index];
                  return StepCard(
                    step: step,
                    isActive: index == state.stepsState.currentIndex,
                    onTap: () {
                      _bloc.add(steps_bloc.JumpToStep(index: index));
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: StepNavigationButtons(
                canGoPrevious: state.stepsState.canGoPrevious,
                canGoNext: state.stepsState.canGoNext || !state.stepsState.isCompleted,
                onPreviousPressed: () {
                  _bloc.add(steps_bloc.NavigateToPreviousStep());
                },
                onNextPressed: () {
                  if (state.stepsState.isCompleted) return;
                   
                  final currentStep = state.stepsState.getCurrentStep();
                  if (currentStep.validationRules != null) {
                    final errors = <StepValidationResult>[];
                    for (final rule in currentStep.validationRules!) {
                      final error = rule.validateStep(currentStep);
                      if (error != null) {
                        errors.add(error);
                      }
                    }
                    
                    if (errors.isNotEmpty) {
                      _bloc.add(steps_bloc.StepValidationFailed(
                        stepId: currentStep.id,
                        errors: errors,
                      ));
                      return;
                    }
                  }
                   
                  if (state.stepsState.currentIndex == state.stepsState.steps.length - 1) {
                    _bloc.add(steps_bloc.CompleteFlow());
                  } else {
                    _bloc.add(steps_bloc.NavigateToNextStep());
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    final state = context.read<steps_bloc.StepBloc>().state;
    
    return AppBar(
      leading:(state.stepsState.canGoPrevious)
            ? IconButton(
               icon: const Icon(Icons.close),
               onPressed: () => context.go('/home'),
             )
            : null,
    );
  }
}
