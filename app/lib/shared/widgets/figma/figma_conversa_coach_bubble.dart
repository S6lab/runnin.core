import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Bubble usada em HIST > VER CONVERSA COM COACH (tela 33).
/// Diferente do `FigmaCoachChatBubble` do live chat, este replay mostra
/// labels claros (`COACH.AI` / `VOCÊ`) com timestamp pequeno ao lado.
enum ConversaAuthor { coach, user }

class FigmaConversaCoachBubble extends StatelessWidget {
  const FigmaConversaCoachBubble({
    super.key,
    required this.author,
    required this.text,
    required this.timestamp,
  });

  final ConversaAuthor author;
  final String text;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final isCoach = author == ConversaAuthor.coach;
    final color = isCoach ? FigmaColors.brandOrange : FigmaColors.brandCyan;
    final label = isCoach ? 'COACH.AI' : 'VOCÊ';
    final timeLabel = DateFormat.Hm().format(timestamp.toLocal());

    final alignment = isCoach ? Alignment.centerLeft : Alignment.centerRight;
    final maxWidth = MediaQuery.of(context).size.width * 0.82;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.041),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeLabel,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: FigmaColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 20 / 13,
                color: FigmaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
