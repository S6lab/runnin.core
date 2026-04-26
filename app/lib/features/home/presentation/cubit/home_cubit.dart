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

  HomeCubit() : _useCase = GetHomeDataUseCase(), super(HomeInitial());

  Future<void> load() async {
    emit(HomeLoading());
    try {
      final data = await _useCase.execute();
      emit(HomeLoaded(data));
    } catch (_) {
      emit(HomeError('Erro ao carregar dados. Tente novamente.'));
    }
  }
}
