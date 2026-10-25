/// Porcentaje de cumplimiento sin decimales, el mismo criterio en toda la app.
/// Redondea, pero nunca muestra 100 % si no se llegó (99.6 → 99 %), para que
/// el número no contradiga al semáforo.
String formatearPorcentaje(double porcentaje) {
  var redondeado = porcentaje.round();
  if (porcentaje < 100 && redondeado >= 100) redondeado = 99;
  return '$redondeado%';
}
