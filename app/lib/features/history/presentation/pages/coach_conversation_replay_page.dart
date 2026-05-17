import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/history/data/coach_message_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_conversa_coach_bubble.dart';

class CoachConversationReplayPage extends StatefulWidget {
  final String runId;
  const CoachConversationReplayPage({super.key, required this.runId});

  @override
  State<CoachConversationReplayPage> createState() => _CoachConversationReplayPageState();
}

class _CoachConversationReplayPageState extends State<CoachConversationReplayPage> {
  final _messageDatasource = CoachMessageRemoteDatasource();
  final _runDatasource = RunRemoteDatasource();
  List<CoachMessageLog>? _messages;
  Run? _run;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _messageDatasource.getMessages(widget.runId),
        _runDatasource.getRun(widget.runId),
      ]);
      if (mounted) {
        setState(() {
          _messages = results[0] as List<CoachMessageLog>;
          _run = results[1] as Run;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro ao carregar conversa.'; _loading = false; });
    }
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat("dd 'de' MMMM, yyyy", 'pt_BR').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  String _fmtDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: FigmaDimensions.backButton,
                      height: FigmaDimensions.backButton,
                      decoration: BoxDecoration(
                        border: Border.all(color: FigmaColors.borderBackBtn, width: FigmaDimensions.borderUniversal),
                      ),
                      child: Icon(Icons.arrow_back, size: 18, color: palette.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RUNIN.AI / COACH',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1,
                          color: palette.secondary,
                        ),
                      ),
                      if (_run != null)
                        Text(
                          _fmtDate(_run!.createdAt).toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.8,
                            color: FigmaColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stat tiles row
            if (_run != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      _MiniStat(label: 'KM', value: (_run!.distanceM / 1000).toStringAsFixed(1)),
                      _MiniStat(label: 'TEMPO', value: _fmtDuration(_run!.durationS)),
                      _MiniStat(label: 'PACE', value: _run!.avgPace ?? '--:--'),
                      if (_run!.avgBpm != null)
                        _MiniStat(label: 'BPM', value: '${_run!.avgBpm}'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // CONVERSA.01 headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'CONVERSA.01',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.3,
                  color: FigmaColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Messages list
            Expanded(child: _buildMessageList()),

            // Footer
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: FigmaColors.surfaceCard,
                border: Border.all(color: FigmaColors.borderDefault),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 14, color: palette.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ANÁLISE VERIFICADA — Baseada em dados reais',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                        color: FigmaColors.textMuted,
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

  Widget _buildMessageList() {
    final palette = context.runninPalette;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: palette.muted)));
    }
    if (_messages == null || _messages!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 40, color: FigmaColors.borderDefault),
            const SizedBox(height: 12),
            Text(
              'Nenhuma conversa com o coach nesta corrida.',
              style: TextStyle(color: palette.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Corridas antigas podem não ter dados de conversa.',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: FigmaColors.textDim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      itemCount: _messages!.length,
      itemBuilder: (_, i) {
        final msg = _messages![i];
        final ts = DateTime.tryParse(msg.createdAt)?.toLocal() ?? DateTime.now();
        return FigmaConversaCoachBubble(
          author: msg.author == 'coach' ? ConversaAuthor.coach : ConversaAuthor.user,
          text: msg.text,
          timestamp: ts,
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: FigmaColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
