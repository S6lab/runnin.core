import 'package:flutter/material.dart';
import 'package:runnin/features/history/presentation/widgets/run_card.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

class RunsListView extends StatelessWidget {
  final List<Run> runs;
  const RunsListView({super.key, required this.runs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: runs.length,
      itemBuilder: (_, i) => RunCard(run: runs[i]),
    );
  }
}
