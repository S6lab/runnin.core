import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/theme/context_extension.dart';
import 'package:runnin/features/badges/domain/entities/badge.dart' as badge_e;
import 'package:runnin/features/badges/presentation/badge_controller.dart';
import 'package:runnin/features/badges/presentation/widgets/badge_card_view.dart';

/// Modal full-screen estilo "stories" exibido quando o user destrava badge
/// novo. Aparece no próximo open do app (não no fim da run).
class BadgePopupModal extends StatefulWidget {
  final badge_e.Badge badge;
  /// True quando o modal foi aberto automaticamente após unlock — fecha
  /// disparando markSeen no server. False quando user abriu da galeria
  /// (badge já visto), só fecha sem network call.
  final bool isAutoUnlock;
  const BadgePopupModal({super.key, required this.badge, this.isAutoUnlock = false});

  static Future<void> show(
    BuildContext context,
    badge_e.Badge badge, {
    bool isAutoUnlock = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => BadgePopupModal(badge: badge, isAutoUnlock: isAutoUnlock),
    );
  }

  @override
  State<BadgePopupModal> createState() => _BadgePopupModalState();
}

class _BadgePopupModalState extends State<BadgePopupModal> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Captura PNG do RepaintBoundary do card.
      final renderObject = _cardKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        Logger.error(
          'badges.share.no_render_object',
          'cardKey context returned null or not RepaintBoundary',
          StackTrace.current,
          {'badgeId': widget.badge.badgeId},
        );
        return;
      }
      final ui.Image img = await renderObject.toImage(pixelRatio: 3.0);
      final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        Logger.error(
          'badges.share.toByteData_null',
          'image.toByteData returned null',
          StackTrace.current,
          {'badgeId': widget.badge.badgeId},
        );
        return;
      }
      final pngBytes = bytes.buffer.asUint8List();
      // Persiste tmp pra share_plus.
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/badge_${widget.badge.badgeId}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.badge.title} · runnin.ai',
      );
      // Best-effort: registra share no server.
      unawaited(BadgeController.instance.trackShare(widget.badge.badgeId));
    } catch (e, st) {
      Logger.error('badges.share.fail', e, st, {'badgeId': widget.badge.badgeId});
    }
    if (mounted) setState(() => _sharing = false);
  }

  Future<void> _close() async {
    // Só dispara markSeen quando é popup automático pós-unlock.
    if (widget.isAutoUnlock) {
      await BadgeController.instance.dismissPopup();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header: close
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: palette.muted.withValues(alpha: 0.3),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: double.infinity,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.text),
                    onPressed: _close,
                  ),
                ],
              ),
            ),
            // Card (full bleed) — em RepaintBoundary pra capturar PNG
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: BadgeCardView(badge: widget.badge),
                  ),
                ),
              ),
            ),
            // CTA: compartilhar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sharing ? null : _share,
                      icon: const Icon(Icons.ios_share),
                      label: Text(_sharing ? 'PREPARANDO...' : 'COMPARTILHAR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.background,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
