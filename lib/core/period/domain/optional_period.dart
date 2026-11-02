/// A year and month that may each be absent: absent means "all".
class OptionalPeriod {
  final int? year;
  final int? month;

  const OptionalPeriod({this.year, this.month});
}
