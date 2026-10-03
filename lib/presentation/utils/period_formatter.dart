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
