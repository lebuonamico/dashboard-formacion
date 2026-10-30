/// Porcentaje de cumplimiento sin decimales, el mismo criterio en toda la app.
/// Redondea, pero nunca muestra 100 % si no se llegó (99.6 → 99 %), para que
/// el número no contradiga al semáforo.
String formatPercentage(double percentage) {
  var rounded = percentage.round();
  if (percentage < 100 && rounded >= 100) rounded = 99;
  return '$rounded%';
}
