import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class StreakCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? accentColor;

  const StreakCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: context.runninType.bodySm),
            Text(value,
                style: context.runninType.dataMd
                    .copyWith(fontWeight: FontWeight.bold)),
            if (unit != null) Text(unit!),
          ],
        ),
      ),
    );
  }
}
