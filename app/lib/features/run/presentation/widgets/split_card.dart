import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class SplitCard extends StatelessWidget {
  const SplitCard({
    super.key,
    required this.kmLabel,
    required this.time,
    this.status = SplitCardStatus.done,
  });

  final String kmLabel;
  final String time;
  final SplitCardStatus status;

  @override
  Widget build(BuildContext context) {
    return FigmaSplitCard(
      kmLabel: kmLabel,
      time: time,
      status: status,
    );
  }
}
