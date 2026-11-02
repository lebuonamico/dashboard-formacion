/// Average credited hours per eligible employee in a month, against the
/// average target of the training plan in effect that month.
class MonthlyHours {
  final DateTime month;
  final double hours;
  final double target;

  const MonthlyHours({
    required this.month,
    required this.hours,
    required this.target,
  });
}
