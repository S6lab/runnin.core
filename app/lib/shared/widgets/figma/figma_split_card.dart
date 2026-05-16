import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Single split card for the run HUD horizontal scroller per
/// `docs/figma/screens/RUN_JOURNEY.md` § active HUD splits.
/// Shows `KM##` label + time, color-coded:
///   - status `done` → orange time
///   - status `pending` → dim time
enum SplitCardStatus { done, pending }

class FigmaSplitCard extends StatelessWidget {
  const FigmaSplitCard({
    super.key,
    required this.kmLabel,
    required this.time,
    this.status = SplitCardStatus.done,
  });

  final String kmLabel; // e.g. "KM03"
  final String time;    // e.g. "5:48"
  final SplitCardStatus status;

  @override
  Widget build(BuildContext context) {
    final timeColor = status == SplitCardStatus.done
        ? FigmaColors.brandOrange
        : FigmaColors.textDim;
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
        borderRadius: FigmaBorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kmLabel,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              height: 16.5 / 11,
              fontWeight: FontWeight.w400,
              color: FigmaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              height: 19.5 / 13,
              fontWeight: FontWeight.w700,
              color: timeColor,
            ),
          ),
        ],
      ),
    );
  }
}
