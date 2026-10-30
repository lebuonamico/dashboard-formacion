enum PeriodScope { monthly, annual }

class PeriodFilter {
  final PeriodScope scope;
  final int month;
  final int year;

  const PeriodFilter({
    required this.scope,
    required this.month,
    required this.year,
  });

  PeriodFilter copyWith({PeriodScope? scope, int? month, int? year}) =>
      PeriodFilter(
        scope: scope ?? this.scope,
        month: month ?? this.month,
        year: year ?? this.year,
      );
}
