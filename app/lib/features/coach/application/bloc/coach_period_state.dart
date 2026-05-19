part of 'coach_period_bloc.dart';

@immutable
abstract class CoachPeriodState extends_equatable {
  const CoachPeriodState();

  @override
  List<Object?> get props => [];
}

class CoachPeriodInitial extends CoachPeriodState {
  const CoachPeriodInitial();

  @override
  String toString() => 'CoachPeriodInitial';
}

class CoachPeriodLoading extends CoachPeriodState {
  const CoachPeriodLoading();

  @override
  String toString() => 'CoachPeriodLoading';
}

class CoachPeriodSuccess extends CoachPeriodState {
  final String summary;

  const CoachPeriodSuccess({required this.summary});

  @override
  List<Object?> get props => [summary];

  @override
  String toString() => 'CoachPeriodSuccess(summary: ${summary.length} chars)';
}

class CoachPeriodError extends CoachPeriodState {
  final String message;

  const CoachPeriodError({required this.message});

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'CoachPeriodError(message: $message)';
}
