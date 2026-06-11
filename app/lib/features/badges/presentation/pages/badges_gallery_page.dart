import 'package:flutter/material.dart';

import 'package:runnin/core/theme/context_extension.dart';
import 'package:runnin/features/badges/data/badge_remote_datasource.dart';
import 'package:runnin/features/badges/domain/entities/badge.dart' as badge_e;
import 'package:runnin/features/badges/presentation/badge_controller.dart';
import 'package:runnin/features/badges/presentation/pages/badge_popup_modal.dart';
import 'package:runnin/features/badges/presentation/widgets/badge_card_view.dart';

/// Galeria de badges — TF 79 mostra TODOS os badges definidos no server,
/// com cadeado nos bloqueados. Pull-to-refresh re-roda evaluator + listByUser.
class BadgesGalleryPage extends StatefulWidget {
  /// Quando true, esconde Scaffold/AppBar — pra usar embedded em outra
  /// página (ex: aba badges em /gamification).
  final bool embedded;
  const BadgesGalleryPage({super.key, this.embedded = false});

  @override
  State<BadgesGalleryPage> createState() => _BadgesGalleryPageState();
}

class _BadgesGalleryPageState extends State<BadgesGalleryPage> {
  final _controller = BadgeController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.loadCatalog();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _refresh() => _controller.loadCatalog();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final body = RefreshIndicator(
      onRefresh: _refresh,
      color: palette.primary,
      child: _build(context, palette, type),
    );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        title: Text('BADGES', style: type.labelCaps.copyWith(letterSpacing: 1.5)),
        centerTitle: false,
        iconTheme: IconThemeData(color: palette.text),
      ),
      body: body,
    );
  }

  Widget _build(BuildContext context, palette, type) {
    final catalog = _controller.catalog;
    if (_controller.loading && catalog.isEmpty) {
      return Center(child: CircularProgressIndicator(color: palette.primary));
    }
    if (catalog.isEmpty) {
      final errored = _controller.lastErrored;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Icon(
                    errored ? Icons.cloud_off_outlined : Icons.emoji_events_outlined,
                    size: 56,
                    color: errored ? palette.warning : palette.muted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errored ? 'Não foi possível carregar' : 'Carregando catálogo…',
                    textAlign: TextAlign.center,
                    style: type.labelMd.copyWith(color: palette.text, fontSize: 18.0),
                  ),
                  if (errored) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: Icon(Icons.refresh, color: palette.primary),
                      label: Text(
                        'TENTAR DE NOVO',
                        style: type.labelCaps.copyWith(
                          color: palette.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Duas seções: CONQUISTADOS em cronologia real (data da corrida que
    // destravou — achievedAt — com fallback no unlockedAt pra badges
    // antigos, mais recente primeiro) e A CONQUISTAR na ordem do catálogo.
    final unlocked = catalog.where((e) => e.unlocked).toList()
      ..sort((a, b) {
        final aTs = a.unlock?.achievedOrUnlockedAt ?? 0;
        final bTs = b.unlock?.achievedOrUnlockedAt ?? 0;
        return bTs.compareTo(aTs);
      });
    final locked = catalog.where((e) => !e.unlocked).toList();

    SliverGrid grid(List<BadgeCatalogEntry> entries) => SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            // TF 79: aspect 1.0 (quadrado) — cabe lockup + hero + label +
            // título 1-linha + data sem overflow vertical.
            childAspectRatio: 1.0,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final entry = entries[i];
              return GestureDetector(
                onTap: () => _openDetail(entry),
                child: BadgeCardView(
                  badge: _toBadge(entry),
                  compact: true,
                  locked: !entry.unlocked,
                ),
              );
            },
            childCount: entries.length,
          ),
        );

    Widget sectionHeader(String label, String counter) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                label,
                style: type.labelCaps.copyWith(
                  color: palette.muted,
                  fontSize: 11.0,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                counter,
                style: type.labelCaps.copyWith(
                  color: palette.primary,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (unlocked.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: sectionHeader(
              'CONQUISTADOS',
              '${unlocked.length} / ${catalog.length}',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: grid(unlocked),
          ),
        ],
        if (locked.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: sectionHeader('A CONQUISTAR', '${locked.length}'),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: grid(locked),
          ),
        ],
      ],
    );
  }

  /// Converte entrada do catálogo em Badge pra reusar o BadgeCardView.
  /// Para locked, gera Badge sintético com os campos da definição (sem stats).
  badge_e.Badge _toBadge(BadgeCatalogEntry entry) {
    if (entry.unlock != null) return entry.unlock!;
    return badge_e.Badge(
      badgeId: entry.badgeId,
      category: _categoryFromString(entry.category),
      title: entry.title,
      subtitle: entry.subtitle,
      description: entry.description,
      badgeChip: 'BLOQUEADO',
      primaryDisplay: '—',
      unlockedAt: 0,
      stats: const badge_e.BadgeStatsSnapshot(),
      seen: true,
    );
  }

  badge_e.BadgeCategory _categoryFromString(String s) {
    switch (s) {
      case 'first':
        return badge_e.BadgeCategory.first;
      case 'distance_total':
        return badge_e.BadgeCategory.distanceTotal;
      case 'distance_run':
        return badge_e.BadgeCategory.distanceRun;
      case 'streak':
        return badge_e.BadgeCategory.streak;
      case 'pace':
        return badge_e.BadgeCategory.pace;
      case 'report':
        return badge_e.BadgeCategory.report;
    }
    return badge_e.BadgeCategory.first;
  }

  void _openDetail(BadgeCatalogEntry entry) {
    final badge = _toBadge(entry);
    BadgePopupModal.show(context, badge);
  }
}
