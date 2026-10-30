bool matchesPeriod(DateTime date, {int? year, int? month}) =>
    (year == null || date.year == year) &&
    (month == null || date.month == month);
