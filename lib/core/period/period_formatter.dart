import 'package:app_finnegans/core/period/period_providers.dart';

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

/// Devuelve el nombre visible del mes para selectores y encabezados.
String monthName(int month) {
  if (month < 1 || month > _months.length) {
    throw RangeError.range(month, 1, _months.length, 'mes');
  }
  return _months[month - 1];
}

String periodLabel(PeriodScope scope, int month, int year) =>
    scope == PeriodScope.annual ? '$year' : '${monthName(month)} $year';

/// Como [periodLabel], pero el anual aclara que solo suma los meses con
/// datos. Para encabezados de detalle y reportes.
String detailedPeriodLabel(PeriodScope scope, int month, int year) =>
    scope == PeriodScope.annual
    ? 'Año $year · meses con datos'
    : '${monthName(month)} $year';
