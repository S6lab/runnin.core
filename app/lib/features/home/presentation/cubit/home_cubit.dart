import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runnin/features/home/domain/use_cases/get_home_data_use_case.dart';

// States
abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final HomeData data;
  HomeLoaded(this.data);
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}

// Cubit
class HomeCubit extends Cubit<HomeState> {
  final GetHomeDataUseCase _useCase;
  Timer? _planPollTimer;
  bool _refreshing = false;

  static const _planPollInterval = Duration(seconds: 10);

  HomeCubit() : _useCase = GetHomeDataUseCase(), super(HomeInitial());

  Future<void> load({bool showLoading = true}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showLoading) emit(HomeLoading());
    try {
      final data = await _useCase.execute();
      if (isClosed) return;
      _syncPlanPolling(data);
      emit(HomeLoaded(data));
    } catch (_) {
      if (!isClosed && showLoading) {
        emit(HomeError('Erro ao carregar dados. Tente novamente.'));
      }
    } finally {
      _refreshing = false;
    }
  }

  void _syncPlanPolling(HomeData data) {
    if (data.plan?.isGenerating == true) {
      _planPollTimer ??= Timer.periodic(
        _planPollInterval,
        (_) => load(showLoading: false),
      );
      return;
    }

    _planPollTimer?.cancel();
    _planPollTimer = null;
  }

  @override
  Future<void> close() {
    _planPollTimer?.cancel();
    return super.close();
  }
}
