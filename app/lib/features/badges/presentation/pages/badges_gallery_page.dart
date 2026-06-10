import 'package:flutter/material.dart';

import 'package:runnin/core/theme/context_extension.dart';
import 'package:runnin/features/badges/domain/entities/badge.dart' as badge_e;
import 'package:runnin/features/badges/presentation/badge_controller.dart';
import 'package:runnin/features/badges/presentation/widgets/badge_card_view.dart';
import 'package:runnin/features/badges/presentation/pages/badge_popup_modal.dart';

class BadgesGalleryPage extends StatefulWidget {
  /// Quando true, esconde AppBar/Scaffold — pra usar embedded em outra
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
    _controller.refresh();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final body = RefreshIndicator(
      onRefresh: _controller.refresh,
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
    if (_controller.loading && _controller.all.isEmpty) {
      return Center(child: CircularProgressIndicator(color: palette.primary));
    }
    if (_controller.all.isEmpty) {
      // Diferencia "vazio porque novato" (sem erro) de "vazio porque
      // request falhou" (lastErrored=true). Sem isso, qualquer falha de
      // rede/server vira "Nenhum badge ainda" enganador e o user fica sem
      // botão de retry.
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
                    errored
                        ? 'Não foi possível carregar'
                        : 'Nenhum badge ainda',
                    textAlign: TextAlign.center,
                    style: type.labelMd.copyWith(color: palette.text, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errored
                        ? 'Verifique sua conexão e toque pra tentar de novo'
                        : 'Conclua corridas pra desbloquear marcos da sua jornada',
                    textAlign: TextAlign.center,
                    style: type.bodySm.copyWith(color: palette.muted),
                  ),
                  if (errored) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _controller.refresh(),
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
                            horizontal: 20, vertical: 12),
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _controller.all.length,
      itemBuilder: (_, i) {
        final b = _controller.all[i];
        return GestureDetector(
          onTap: () => _openDetail(b),
          child: BadgeCardView(badge: b, compact: true),
        );
      },
    );
  }

  void _openDetail(badge_e.Badge b) {
    BadgePopupModal.show(context, b);
  }
}
