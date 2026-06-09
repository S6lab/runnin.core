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
  /// Cursor da próxima página. Null = primeira página foi última.
  final String? nextCursor;
  /// True enquanto loadMore está em vôo (pra UI mostrar spinner no fim).
  final bool loadingMore;
  const NotificationsLoaded(
    this.items, {
    this.nextCursor,
    this.loadingMore = false,
  });

  bool get hasMore => nextCursor != null;

  NotificationsLoaded copyWith({
    List<AppNotification>? items,
    String? nextCursor,
    bool? loadingMore,
    bool clearCursor = false,
  }) => NotificationsLoaded(
        items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loadingMore: loadingMore ?? this.loadingMore,
      );
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
      final page = await _ds.list();
      if (isClosed) return;
      // Fix TF 59: dedup defensivo na primeira página. User reportou cards
      // duplicados — bug raiz no server (dedupeKey volátil), mas dedup do
      // front-end protege em qualquer regressão futura.
      final seen = <String>{};
      final unique = page.items.where((n) => seen.add(n.id)).toList();
      emit(NotificationsLoaded(unique, nextCursor: page.nextCursor));
    } catch (_) {
      if (isClosed) return;
      emit(const NotificationsError('Erro ao carregar notificações.'));
    }
  }

  /// Carrega a próxima página e appenda. No-op se não há mais ou já está
  /// carregando. Falha silenciosa (mantém estado, só desliga o spinner).
  Future<void> loadMore() async {
    final current = state;
    if (current is! NotificationsLoaded) return;
    if (!current.hasMore || current.loadingMore) return;

    emit(current.copyWith(loadingMore: true));
    try {
      final page = await _ds.list(cursor: current.nextCursor);
      if (isClosed) return;
      // Dedupe defensivo: se o server retornar item já presente
      // (ex: race com createIfAbsent), ignora o duplicado.
      final existingIds = current.items.map((n) => n.id).toSet();
      final newItems = page.items.where((n) => !existingIds.contains(n.id));
      emit(NotificationsLoaded(
        [...current.items, ...newItems],
        nextCursor: page.nextCursor,
        loadingMore: false,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(current.copyWith(loadingMore: false));
    }
  }

  Future<void> dismiss(String id) async {
    final current = state;
    if (current is! NotificationsLoaded) return;

    // Otimista: remove da lista, refaz se a request falhar.
    final next = current.items.where((n) => n.id != id).toList();
    emit(current.copyWith(items: next));

    try {
      await _ds.dismiss(id);
    } catch (_) {
      if (isClosed) return;
      emit(current);
    }
  }

  /// Marca como visualizada (readAt). Reduz o badge da home e deixa a borda
  /// do card em estado "lido". Idempotente: se já estava lida, no-op.
  /// Otimista: aplica localmente, reverte se a request falhar.
  Future<void> markRead(String id) async {
    final current = state;
    if (current is! NotificationsLoaded) return;
    final idx = current.items.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final target = current.items[idx];
    if (target.readAt != null) return;

    final updated = target.copyWith(readAt: DateTime.now());
    final next = [...current.items];
    next[idx] = updated;
    emit(current.copyWith(items: next));

    try {
      await _ds.markRead(id);
    } catch (_) {
      if (isClosed) return;
      emit(current);
    }
  }

  Future<void> clear() async {
    final current = state;
    if (current is! NotificationsLoaded || current.items.isEmpty) return;

    emit(const NotificationsLoaded([], nextCursor: null));

    try {
      await _ds.clear();
    } catch (_) {
      if (isClosed) return;
      emit(current);
    }
  }
}
