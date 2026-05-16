import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaBenchmarkTable extends StatelessWidget {
  const FigmaBenchmarkTable({
    super.key,
    required this.benchmarkData,
  });

  final List<BenchmarkRow> benchmarkData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.735),
      ),
      child: Column(
        children: benchmarkData.map((row) => RowItem(row: row)).toList(),
      ),
    );
  }
}

class BenchmarkRow {
  final String label;
  final String userValue;
  final String cohortValue;
  final bool betterIsLower;

  const BenchmarkRow({
    required this.label,
    required this.userValue,
    required this.cohortValue,
    required this.betterIsLower,
  });
}

class RowItem extends StatelessWidget {
  final BenchmarkRow row;

  const RowItem({required this.row});

  @override
  Widget build(BuildContext context) {
    final isBetter = row.betterIsLower
        ? compareValues(row.userValue, row.cohortValue) < 0
        : compareValues(row.userValue, row.cohortValue) > 0;
    final color = isBetter
        ? FigmaColors.textPrimary
        : FigmaColors.brandCyan;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w500,
               color: FigmaColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.userValue,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: FigmaColors.brandCyan,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                row.cohortValue,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int compareValues(String user, String cohort) {
    final userNum = double.tryParse(user.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final cohortNum = double.tryParse(cohort.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    if (userNum < cohortNum) return -1;
    if (userNum > cohortNum) return 1;
    return 0;
  }
}
