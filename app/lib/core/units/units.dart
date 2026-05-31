import 'package:intl/intl.dart';

enum UnitsSystem { metric, imperial }

enum PaceFormat { minPerKm, minPerMi }

class UnitsHelper {
  const UnitsHelper({
    this.unitsSystem = UnitsSystem.metric,
    this.paceFormat = PaceFormat.minPerKm,
  });

  final UnitsSystem unitsSystem;
  final PaceFormat paceFormat;

  String formatDistance(double meters) {
    if (unitsSystem == UnitsSystem.imperial) {
      final feet = meters * 3.28084;
      final miles = feet / 5280;
      if (miles >= 1) {
        return '${_formatNumber(miles, decimalDigits: 2)} mi';
      }
      return '${_formatNumber(feet, decimalDigits: 0)} ft';
    }
    if (meters >= 1000) {
      return '${_formatNumber(meters / 1000, decimalDigits: 2)} km';
    }
    return '${_formatNumber(meters, decimalDigits: 0)} m';
  }

  String formatWeight(double kg) {
    if (unitsSystem == UnitsSystem.imperial) {
      final pounds = kg * 2.20462;
      return '${_formatNumber(pounds, decimalDigits: 1)} lb';
    }
    return '${_formatNumber(kg, decimalDigits: 1)} kg';
  }

  String formatHeight(double cm) {
    if (unitsSystem == UnitsSystem.imperial) {
      final inches = cm * 0.393701;
      final totalInches = inches.round();
      final feet = totalInches ~/ 12;
      final remainingInches = totalInches % 12;
      if (feet > 0) {
        return '$feet\'$remainingInches"';
      }
      return '${_formatNumber(inches, decimalDigits: 1)} in';
    }
    if (cm >= 100) {
      return '${_formatNumber(cm / 100, decimalDigits: 2)} m';
    }
    return '${_formatNumber(cm, decimalDigits: 0)} cm';
  }

  String formatPace(double minPerKm) {
    if (paceFormat == PaceFormat.minPerMi && unitsSystem == UnitsSystem.imperial) {
      final minPerMi = minPerKm * 1.60934;
      return _formatPaceValue(minPerMi);
    }
    return _formatPaceValue(minPerKm);
  }

  String _formatNumber(double value, {int decimalDigits = 0}) {
    if (decimalDigits == 0) {
      return value.round().toString();
    }
    final formatter = NumberFormat('#,##0.${'0' * decimalDigits}');
    return formatter.format(value);
  }

  String _formatPaceValue(double minPerUnit) {
    final minutes = minPerUnit.floor();
    final seconds = ((minPerUnit - minutes) * 60).round();
    if (seconds == 60) {
      return '${minutes + 1}:00';
    }
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutes:$secondsStr';
  }
}
