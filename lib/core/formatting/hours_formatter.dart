/// Whole hours, rounded half away from zero: `8`, `2` for 1.5.
String formatHours(double hours) => '${hours.round()}';

/// [value] with [digits] decimals and a decimal comma, as read in Argentina:
/// `1,5`.
String formatDecimal(double value, {int digits = 1}) =>
    value.toStringAsFixed(digits).replaceAll('.', ',');

/// Whole hours without decimals (`8`), the rest with one (`1,5`). Only for
/// the figures that keep decimals: the category progress chips, the courses'
/// average per person, the monthly evolution and the hours per person that
/// the monthly variation badge compares.
/// Rounds to the tenth first, so 4.96 reads `5` (not `5,0`) and 4.35 reads
/// `4,4` (`toStringAsFixed` alone gives `4.3`).
String formatHoursPrecise(double hours) {
  final tenths = (hours * 10).round();
  return tenths % 10 == 0 ? '${tenths ~/ 10}' : formatDecimal(tenths / 10);
}

/// Achieved hours towards [target], rounded. Below the target it never
/// rounds up to it (7.6 of 8 reads `7`), like `formatPercentage`.
String formatAchievedHours(double hours, {required double target}) {
  final rounded = hours.round();
  final roundedTarget = target.round();
  if (hours < target && roundedTarget > 0 && rounded >= roundedTarget) {
    return '${roundedTarget - 1}';
  }
  return '$rounded';
}

/// Hours still missing, rounded up so that something missing never reads
/// `0`: 0.3 reads `1`.
String formatMissingHours(double hours) =>
    hours <= 0 ? '0' : '${(hours - 1e-9).ceil()}';

/// Whole hours above or below the target, signed: `+2 hs`, `-2 hs`. Rounds
/// to `0 hs` without a sign.
String formatHoursDeviation(double deviation) {
  final rounded = deviation.round();
  if (rounded == 0) return '0 hs';
  return '${rounded > 0 ? '+' : '-'}${rounded.abs()} hs';
}
