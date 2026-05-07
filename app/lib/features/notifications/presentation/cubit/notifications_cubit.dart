import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runnin/features/notifications/data/notification_remote_datasource.dart';
import 'package:runnin/features/notifications/domain/entities/app_notification.dart';

abstract class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<AppNotification> items;
  const NotificationsLoaded(this.items);
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError(this.message);
}

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationRemoteDatasource _ds;

  NotificationsCubit({NotificationRemoteDatasource? datasource})
      : _ds = datasource ?? NotificationRemoteDatasource(),
        super(const NotificationsInitial());

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) emit(const NotificationsLoading());
    try {
      final items = await _ds.list();
      if (isClosed) return;
      emit(NotificationsLoaded(items));
    } catch (_) {
      if (isClosed) return;
      emit(const NotificationsError('Erro ao carregar notificações.'));
    }
  }

  Future<void> dismiss(String id) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    // Otimista: remove da lista, refaz se a request falhar.
    final next = current.items.where((n) => n.id != id).toList();
    emit(NotificationsLoaded(next));

    try {
      await _ds.dismiss(id);
    } catch (_) {
      if (isClosed) return;
      emit(NotificationsLoaded(current.items));
    }
  }

  Future<void> clear() async {
    final current = state;
    if (current is! NotificationsLoaded || current.items.isEmpty) return;

    emit(const NotificationsLoaded([]));

    try {
      await _ds.clear();
    } catch (_) {
      if (isClosed) return;
      emit(NotificationsLoaded(current.items));
    }
  }
}
