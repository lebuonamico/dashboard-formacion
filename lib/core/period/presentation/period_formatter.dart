import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';

const _months = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

String monthName(int month) {
  if (month < 1 || month > _months.length) {
    throw RangeError.range(month, 1, _months.length, 'mes');
  }
  return _months[month - 1];
}

String periodLabel(PeriodScope scope, int month, int year) =>
    scope == PeriodScope.annual ? '$year' : '${monthName(month)} $year';

/// Like [periodLabel], but the annual label says it only adds the months
/// with data. For detail headers and reports.
String detailedPeriodLabel(PeriodScope scope, int month, int year) =>
    scope == PeriodScope.annual
    ? 'Año $year · meses con datos'
    : '${monthName(month)} $year';

extension PeriodScopeLabel on PeriodScope {
  String get label => switch (this) {
    PeriodScope.monthly => 'Mensual',
    PeriodScope.annual => 'Anual',
  };
}
