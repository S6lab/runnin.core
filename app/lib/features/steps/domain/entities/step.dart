import 'package:flutter/widgets.dart';

enum StepStatus { idle, active, completed, error, skipped }

class AppStep {
  final String id;
  final String title;
  final String? description;
  final bool isRequired;
  final StepStatus status;
  final Map<String, dynamic> data;
  final List<StepValidationRule>? validationRules;
  final Widget content;
  final bool isLastStep;

  const AppStep({
    required this.id,
    required this.title,
    this.description,
    this.isRequired = true,
    this.status = StepStatus.idle,
    this.data = const {},
    this.validationRules,
    required this.content,
    this.isLastStep = false,
  });

  AppStep copyWith({
    String? id,
    String? title,
    String? description,
    bool? isRequired,
    StepStatus? status,
    Map<String, dynamic>? data,
    List<StepValidationRule>? validationRules,
    Widget? content,
    bool? isLastStep,
  }) {
    return AppStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isRequired: isRequired ?? this.isRequired,
      status: status ?? this.status,
      data: data ?? this.data,
      validationRules: validationRules ?? this.validationRules,
      content: content ?? this.content,
      isLastStep: isLastStep ?? this.isLastStep,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'isRequired': isRequired,
      'status': status.name,
      'data': data,
      if (validationRules != null) 'validationRules': validationRules!.map((e) => e.toJson()).toList(),
    };
  }
}

class StepValidationRule {
  final String field;
  final String message;
  final bool Function(dynamic value) validate;

  const StepValidationRule({
    required this.field,
    required this.message,
    required this.validate,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'message': message,
    };
  }

  factory StepValidationRule.fromJson(Map<String, dynamic> json) {
    return StepValidationRule(
      field: json['field'] as String,
      message: json['message'] as String,
      validate: (_) => true,
    );
  }

  StepValidationResult? validateStep(AppStep step) {
    final value = step.data[field];
    if (value == null || !validate(value)) {
      return StepValidationResult(
        isValid: false,
        message: message,
        field: field,
      );
    }
    return null;
  }
}

class StepValidationResult {
  final bool isValid;
  final String message;
  final String field;

  const StepValidationResult({
    required this.isValid,
    required this.message,
    required this.field,
  });
}

class StepsState {
  final List<AppStep> steps;
  final int currentIndex;
  final bool isCompleted;

  const StepsState({
    this.steps = const [],
    this.currentIndex = 0,
    this.isCompleted = false,
  });

  StepsState copyWith({
    List<AppStep>? steps,
    int? currentIndex,
    bool? isCompleted,
  }) {
    return StepsState(
      steps: steps ?? this.steps,
      currentIndex: currentIndex ?? this.currentIndex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  AppStep getCurrentStep() => steps[currentIndex];

  bool get canGoNext => currentIndex < steps.length - 1;
  bool get canGoPrevious => currentIndex > 0;

  AppStep? getNextStep() {
    if (!canGoNext) return null;
    return steps[currentIndex + 1];
  }

  AppStep? getPreviousStep() {
    if (!canGoPrevious) return null;
    return steps[currentIndex - 1];
  }
}
