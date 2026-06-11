import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Wearable device card for PERFIL > SAÚDE > DISPOSITIVOS per
/// `docs/figma/screens/PERFIL.md`. Two variants:
///   - [FigmaDeviceConnectedCard] — connected device with status dot
///   - [FigmaCompatibleDeviceCard] — list item with "Conectar ↗" CTA
class FigmaDeviceConnectedCard extends StatelessWidget {
  const FigmaDeviceConnectedCard({
    super.key,
    required this.deviceName,
    required this.platformLabel,
    required this.dataChips,
    this.onSync,
  });

  final String deviceName;
  final String platformLabel;
  final List<String> dataChips; // e.g. ["BPM", "STEPS", "SLEEP"]
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13.718),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCardCyan,
        border: Border.all(color: context.runninPalette.primary, width: 1.041),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.runninPalette.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CONECTADO',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w500,
                  color: context.runninPalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            deviceName,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textPrimary,
            ),
          ),
          Text(
            platformLabel,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w400,
              color: FigmaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: dataChips
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    color: context.runninPalette.primary.withValues(alpha: 0.14),
                    child: Text(
                      c,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                        color: context.runninPalette.primary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          if (onSync != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onSync,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'SINCRONIZAR  ↗',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w500,
                  color: context.runninPalette.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FigmaCompatibleDeviceCard extends StatelessWidget {
  const FigmaCompatibleDeviceCard({
    super.key,
    required this.icon,
    required this.deviceName,
    required this.dataLabel,
    this.onConnect,
    this.isConnected = false,
    this.locked = false,
  });

  final IconData icon;
  final String deviceName;
  final String dataLabel; // e.g. "BPM · Sono · Passos"
  final VoidCallback? onConnect;
  /// Quando true, mostra "✓ Conectado" em vez de "Conectar ↗" e desabilita o
  /// tap. Source-of-truth fica fora do card (profile.hasWearable +
  /// healthSyncService.hasPermissions()).
  final bool isConnected;
  /// Plataforma indisponível neste device (ex: Health Connect no iPhone):
  /// cadeado no lugar do CTA, tap desabilitado, visual esmaecido.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return GestureDetector(
      onTap: (isConnected || locked) ? null : onConnect,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: locked ? 0.55 : 1.0,
        child: Container(
        padding: const EdgeInsets.all(13.718),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(
            color: isConnected ? palette.primary.withValues(alpha: 0.5) : FigmaColors.borderDefault,
            width: 1.041,
          ),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle_outline : icon,
              size: 22,
              color: isConnected ? palette.primary : FigmaColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    deviceName,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      height: 19.5 / 13,
                      fontWeight: FontWeight.w500,
                      color: FigmaColors.textPrimary,
                    ),
                  ),
                  Text(
                    dataLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: FigmaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (locked)
              Icon(
                Icons.lock_outline,
                size: 18,
                color: FigmaColors.textMuted,
              )
            else
              Text(
                isConnected ? '✓ Conectado' : 'Conectar  ↗',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  letterSpacing: 0.55,
                  fontWeight: FontWeight.w500,
                  color: palette.primary,
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
