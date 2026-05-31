import 'package:flutter/material.dart';

class PlanProgressBar extends StatelessWidget {
  final double progress;
  
  const PlanProgressBar({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity * progress,
            color: const Color(0xFF00D4FF),
          ),
        ],
      ),
    );
  }
}
