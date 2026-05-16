import 'package:flutter/material.dart';

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
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(value,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            if (unit != null) Text(unit!),
          ],
        ),
      ),
    );
  }
}
