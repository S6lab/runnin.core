import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/steps/domain/entities/step.dart';
import 'package:runnin/features/steps/presentation/bloc/step_bloc.dart';

void main() {
  group('StepBloc', () {
    test('initial state is correct', () {
      final bloc = StepBloc();
      expect(bloc.state.stepsState.steps, isEmpty);
      expect(bloc.state.stepsState.currentIndex, 0);
      expect(bloc.state.stepsState.isCompleted, false);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.errorMessage, null);
      bloc.close();
    });

    test('StepInitialized event initializes steps', () async {
      final bloc = StepBloc();
      final steps = [
        AppStep(id: '1', title: 'Test 1', content: Container()),
        AppStep(id: '2', title: 'Test 2', content: Container()),
      ];
      
      bloc.add(StepInitialized(steps: steps));
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(bloc.state.stepsState.steps.length, 2);
      bloc.close();
    });

    test('NavigateToNextStep increments index', () async {
      final bloc = StepBloc();
      final steps = [
        AppStep(id: '1', title: 'Test 1', content: Container()),
        AppStep(id: '2', title: 'Test 2', content: Container()),
      ];
      
      bloc.add(StepInitialized(steps: steps));
      await Future.delayed(Duration(milliseconds: 100));
      expect(bloc.state.stepsState.currentIndex, 0);
      
      bloc.add(NavigateToNextStep());
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(bloc.state.stepsState.currentIndex, 1);
      bloc.close();
    });

    test('NavigateToPreviousStep decrements index', () async {
      final bloc = StepBloc();
      final steps = [
        AppStep(id: '1', title: 'Test 1', content: Container()),
        AppStep(id: '2', title: 'Test 2', content: Container()),
      ];
      
      bloc.add(StepInitialized(steps: steps));
      await Future.delayed(Duration(milliseconds: 100));
      
      bloc.add(NavigateToNextStep());
      await Future.delayed(Duration(milliseconds: 100));
      
      bloc.add(NavigateToPreviousStep());
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(bloc.state.stepsState.currentIndex, 0);
      bloc.close();
    });

    test('JumpToStep jumps to specific index', () async {
      final bloc = StepBloc();
      final steps = [
        AppStep(id: '1', title: 'Test 1', content: Container()),
        AppStep(id: '2', title: 'Test 2', content: Container()),
        AppStep(id: '3', title: 'Test 3', content: Container()),
      ];
      
      bloc.add(StepInitialized(steps: steps));
      await Future.delayed(Duration(milliseconds: 100));
      expect(bloc.state.stepsState.currentIndex, 0);
      
      bloc.add(JumpToStep(index: 2));
      await Future.delayed(Duration(milliseconds: 100));
      expect(bloc.state.stepsState.currentIndex, 2);
      bloc.close();
    });
  });
}
