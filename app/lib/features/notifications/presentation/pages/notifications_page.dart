import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/notifications/domain/entities/app_notification.dart';
import 'package:runnin/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:runnin/features/notifications/presentation/notification_routes.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';

/// Tela de Notificações (nova arquitetura): lista plana, sem agrupamento por
/// categoria. Substitui o dropdown "Central" da Home — agora aberta pelo sino
/// no cabeçalho. Modelo extensível (cada item: tipo, título, corpo, CTA).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Cubit vem do MainLayout (shell) — mesma instância usada pelo badge
    // da home. Aqui só dispara refresh pra pegar novidades enquanto a
    // tela está aberta (silent refresh, sem flicker de loading).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsCubit>().load(showLoading: false);
    });
  }

  @override
  Widget build(BuildContext context) => const _NotificationsView();
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Dispara loadMore quando faltam 200px pro fim. Threshold confortável
  /// pra usuário não ver "fim da lista" antes do fetch começar.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 200) {
      context.read<NotificationsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: RunninAppBar(
        title: 'NOTIFICAÇÕES',
        fallbackRoute: '/home',
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              final has = state is NotificationsLoaded && state.items.isNotEmpty;
              if (!has) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => context.read<NotificationsCubit>().clear(),
                child: const Text('LIMPAR'),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsLoading || state is NotificationsInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is NotificationsError) {
            return Center(
              child: Text(state.message, style: TextStyle(color: palette.muted)),
            );
          }
          final loaded = state is NotificationsLoaded ? state : null;
          final items = loaded?.items ?? const <AppNotification>[];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_outlined, size: 48, color: palette.muted),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhuma notificação por aqui.',
                      style: context.runninType.bodyMd.copyWith(color: palette.muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final loadingMore = loaded?.loadingMore ?? false;
          // +1 slot só quando carregando mais, pra render o spinner footer.
          final itemCount = items.length + (loadingMore ? 1 : 0);
          return ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i >= items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _NotificationTile(item: items[i]);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  const _NotificationTile({required this.item});

  void _onTap(BuildContext context) {
    // Tap marca como lida (otimista — badge cai imediatamente) e navega
    // pra área correspondente ao tipo. Mantém a notif na lista, só muda
    // o estado visual (borda some) — user precisa swipe pra apagar.
    context.read<NotificationsCubit>().markRead(item.id);
    final route = routeForNotification(item);
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final unread = item.readAt == null;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => context.read<NotificationsCubit>().dismiss(item.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: palette.surfaceAlt,
        child: Icon(Icons.close, color: palette.muted, size: 20),
      ),
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(
              color: unread ? palette.primary.withValues(alpha: 0.4) : palette.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: unread ? palette.primary : palette.muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.title, style: type.labelMd)),
                        if (item.timeLabel != null)
                          Text(item.timeLabel!, style: type.dataXs.copyWith(color: palette.muted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.body, style: type.bodySm.copyWith(color: palette.muted)),
                    if (item.ctaLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.ctaLabel!,
                        style: type.labelCaps.copyWith(color: palette.primary),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
