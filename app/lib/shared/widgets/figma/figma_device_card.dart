import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        border: Border.all(color: FigmaColors.brandCyan, width: 1.041),
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
                decoration: const BoxDecoration(
                  color: FigmaColors.brandCyan,
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
                  color: FigmaColors.brandCyan,
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
                    color: FigmaColors.brandCyan.withValues(alpha: 0.14),
                    child: Text(
                      c,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                        color: FigmaColors.brandCyan,
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
                  color: FigmaColors.brandCyan,
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
  });

  final IconData icon;
  final String deviceName;
  final String dataLabel; // e.g. "BPM · Sono · Passos"
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onConnect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(13.718),
        decoration: BoxDecoration(
          color: FigmaColors.surfaceCard,
          border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: FigmaColors.textSecondary),
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
            Text(
              'Conectar  ↗',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                letterSpacing: 0.55,
                fontWeight: FontWeight.w500,
                color: FigmaColors.brandCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
