import 'package:flutter/material.dart';

class CoachAIBreadcrumb extends StatelessWidget {
  final String action;
  
  const CoachAIBreadcrumb({
    super.key,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          color: const Color(0xFF050510),
          child: Center(
            child: Container(
              width: 9.986,
              height: 9.986,
              color: const Color(0xE3FF6B35),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'COACH.AI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.8,
                color: Color(0xFFFF6B35),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              ' > $action',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.8,
                color: Color(0xFF555555),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
