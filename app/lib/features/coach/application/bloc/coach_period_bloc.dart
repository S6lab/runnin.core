import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/coach_report.dart';
import '../datasources/coach_period_remote_datasource.dart';

part 'coach_period_state.dart';

class CoachPeriodEvent extends_equatable {
  const CoachPeriodEvent();

  @override
  List<Object?> get props => [];
}

class LoadCoachPeriodAnalysis extends CoachPeriodEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadCoachPeriodAnalysis({
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [startDate, endDate];
}

class CoachPeriodBloc extends Bloc<CoachPeriodEvent, CoachPeriodState> {
  final CoachPeriodRemoteDatasource _datasource;

  CoachPeriodBloc(this._datasource) : super(const CoachPeriodState.initial()) {
    on<LoadCoachPeriodAnalysis>(_onLoadCoachPeriodAnalysis);
  }

  Future<void> _onLoadCoachPeriodAnalysis(
    LoadCoachPeriodAnalysis event,
    Emitter<CoachPeriodState> emit,
  ) async {
    emit(const CoachPeriodState.loading());

    try {
      final startDateStr = event.startDate.toIso8601String().split('T')[0];
      final endDateStr = event.endDate.toIso8601String().split('T')[0];
      final response = await _datasource.getPeriodAnalysis(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (response['status'] == 'ready') {
        emit(CoachPeriodState.success(
          summary: response['summary'] as String? ?? '',
        ));
      } else {
        emit(CoachPeriodState.error(
          message: response['message'] as String? ?? 'Falha ao carregar análise',
        ));
      }
    } catch (e) {
      emit(CoachPeriodState.error(
        message: e is DioException ? e.message : 'Erro desconhecido',
      ));
    }
  }
}
