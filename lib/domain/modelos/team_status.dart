/// Leandro: Estado calculado por EquiposService; los colores se asignan en la UI.
enum EstadoEquipo {
  enObjetivo('En objetivo'),
  enRiesgo('En riesgo'),
  critico('Crítico');

  final String label;
  const EstadoEquipo(this.label);
}
