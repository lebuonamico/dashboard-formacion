/// Whole hours without decimals (`8`), the rest with one (`1.5`).
String formatHours(double hours) => hours == hours.roundToDouble()
    ? hours.toStringAsFixed(0)
    : hours.toStringAsFixed(1);

/// Hours above or below the target, always signed: `+1.5 hs`, `-2.0 hs`.
String formatHoursDeviation(double deviation, {String unit = 'hs'}) {
  final sign = deviation >= 0 ? '+' : '-';
  return '$sign${deviation.abs().toStringAsFixed(1)} $unit';
}
