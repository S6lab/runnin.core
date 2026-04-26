import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runnin/features/dashboard/data/datasources/dashboard_datasource.dart';
import 'package:runnin/features/dashboard/domain/dashboard_stats.dart';

abstract class DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  DashboardLoaded(this.stats);
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardDatasource _ds;

  DashboardCubit() : _ds = DashboardDatasource(), super(DashboardLoading());

  Future<void> load() async {
    emit(DashboardLoading());
    try {
      final stats = await _ds.load();
      emit(DashboardLoaded(stats));
    } catch (_) {
      emit(DashboardError('Erro ao carregar analytics. Tente novamente.'));
    }
  }
}
