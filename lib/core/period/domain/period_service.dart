import 'package:app_finnegans/core/period/domain/period_filter.dart';

class PeriodService {
  const PeriodService();

  bool isAnnual(PeriodFilter period) => period.scope == PeriodScope.annual;

  bool contains(DateTime date, {int? year, int? month}) =>
      (year == null || date.year == year) &&
      (month == null || date.month == month);

  bool containsInPeriod(PeriodFilter period, DateTime date) => contains(
    date,
    year: period.year,
    month: isAnnual(period) ? null : period.month,
  );
}
