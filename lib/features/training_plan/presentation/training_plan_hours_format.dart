String formatPlanHours(double hours) => hours == hours.roundToDouble()
    ? hours.toStringAsFixed(0)
    : hours.toString().replaceAll('.', ',');

/// Accepts a decimal comma. Rounded to 2 decimals, like the database.
double? parsePlanHours(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value == null ? null : (value * 100).round() / 100;
}
