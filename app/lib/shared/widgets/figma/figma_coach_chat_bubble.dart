import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Coach.AI chat bubble per `docs/figma/screens/TREINO.md` §"Bubble usuário"
/// and §"Bubble Coach.AI" (also used in HIST coach-chat post-run).
///
/// Two variants via [author]:
///   - `ChatBubbleAuthor.user` — right-aligned, cyan-tinted bg + cyan border
///   - `ChatBubbleAuthor.coach` — left-aligned, surface bg, "COACH.AI" label
///     in orange + body text 85% white
///
/// Pass optional [timestamp] to show "HH:mm" at the bottom of the bubble.
enum ChatBubbleAuthor { user, coach }

class FigmaCoachChatBubble extends StatelessWidget {
  const FigmaCoachChatBubble({
    super.key,
    required this.author,
    required this.message,
    this.timestamp,
    this.maxWidth = 300.783,
    this.coachLabel = 'COACH.AI',
  });

  final ChatBubbleAuthor author;
  final String message;
  final String? timestamp;
  final double maxWidth;
  final String coachLabel;

  bool get _isUser => author == ChatBubbleAuthor.user;

  @override
  Widget build(BuildContext context) {
    final bg = _isUser
        ? const Color(0x1200D4FF) // rgba(0,212,255,0.07)
        : FigmaColors.surfaceCard; // rgba(255,255,255,0.03)
    final borderColor = _isUser
        ? const Color(0x3000D4FF) // rgba(0,212,255,0.19)
        : FigmaColors.borderDefault; // rgba(255,255,255,0.08)
    return Row(
      mainAxisAlignment:
          _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.fromLTRB(17.73, 17.73, 17.73, 12),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: borderColor, width: 1.041),
              borderRadius: FigmaBorderRadius.zero,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isUser) ...[
                  Text(
                    coachLabel,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      height: 15 / 10,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w400,
                      color: FigmaColors.brandOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  message,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    height: 21.45 / 13,
                    fontWeight: FontWeight.w400,
                    color: _isUser
                        ? FigmaColors.textPrimary
                        : const Color(0xD9FFFFFF), // rgba(255,255,255,0.85)
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    timestamp!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      height: 15 / 10,
                      fontWeight: FontWeight.w400,
                      color: const Color(0x33FFFFFF), // rgba(255,255,255,0.20)
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
}
