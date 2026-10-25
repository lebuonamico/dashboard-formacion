import 'package:app_finnegans/presentation/providers/period_providers.dart';

const _meses = [
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
String nombreMes(int mes) {
  if (mes < 1 || mes > _meses.length) {
    throw RangeError.range(mes, 1, _meses.length, 'mes');
  }
  return _meses[mes - 1];
}

String etiquetaPeriodo(AlcancePeriodo alcance, int mes, int anio) =>
    alcance == AlcancePeriodo.anual ? '$anio' : '${nombreMes(mes)} $anio';

/// Como [etiquetaPeriodo], pero el anual aclara que solo suma los meses con
/// datos. Para encabezados de detalle y reportes.
String etiquetaPeriodoDetallada(AlcancePeriodo alcance, int mes, int anio) =>
    alcance == AlcancePeriodo.anual
    ? 'Año $anio · meses con datos'
    : '${nombreMes(mes)} $anio';
