import 'package:intl/intl.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

class RunFeedback {
  const RunFeedback({
    required this.run,
    required this.summary,
    required this.generatedAt,
    required this.isLatest,
  });

  final Run run;
  final String summary;
  final String? generatedAt;
  final bool isLatest;

  String get title => run.type.toUpperCase();

  String get dateLabel {
    final parsed = DateTime.tryParse(run.createdAt);
    if (parsed == null) return '--/--';
    return DateFormat('dd/MM').format(parsed.toLocal());
  }

  double get totalKm => run.distanceM / 1000;

  String get durationLabel => _formatDuration(run.durationS);

  String get paceLabel => run.avgPace ?? '--:--';

  String get coachSummary => summary;

  String _formatDuration(int durationS) {
    final minutes = durationS ~/ 60;
    final seconds = durationS % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
