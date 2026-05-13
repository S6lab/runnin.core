import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/coach/data/datasources/coach_report_remote_datasource.dart';
import 'package:runnin/features/coach/domain/entities/coach_report.dart';
import 'package:runnin/shared/widgets/app_tag.dart';

class CoachConversationPage extends StatefulWidget {
  final String runId;
  const CoachConversationPage({super.key, required this.runId});

  @override
  State<CoachConversationPage> createState() => _CoachConversationPageState();
}

class _CoachConversationPageState extends State<CoachConversationPage> {
  final _reportDs = CoachReportRemoteDatasource();
  CoachReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final report = await _reportDs.getReport(widget.runId);
      if (!mounted) return;
      setState(() { _report = report; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.text),
          onPressed: () => context.pop(),
        ),
        title: Text('COACH.AI', style: type.displaySm),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Coach message
                _MessageBubble(
                  role: 'Coach',
                  message: _report?.summary ?? 'Análise não disponível para esta corrida.',
                  time: _report?.generatedAt ?? '',
                  isReady: _report?.isReady ?? false,
                  palette: palette,
                  type: type,
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Histórico completo de conversas disponível em breve.',
                    style: type.bodySm.copyWith(color: palette.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String role;
  final String message;
  final String time;
  final bool isReady;
  final RunninPalette palette;
  final RunninTypography type;

  const _MessageBubble({
    required this.role,
    required this.message,
    required this.time,
    required this.isReady,
    required this.palette,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isCoach = role == 'Coach';
    return Column(
      crossAxisAlignment: isCoach ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(role, style: type.labelMd),
            const SizedBox(width: 8),
            if (isReady)
              AppTag(label: 'VERIFIED ANALYSIS', color: palette.primary),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCoach
                ? palette.primary.withValues(alpha: 0.06)
                : palette.surfaceAlt,
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: type.bodyMd.copyWith(height: 1.6)),
              const SizedBox(height: 8),
              if (time.isNotEmpty)
                Text(
                  _fmtTime(time),
                  style: type.labelCaps.copyWith(color: palette.muted),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtTime(String iso) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}
