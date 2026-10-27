enum TeamStatus {
  onTarget('En objetivo'),
  atRisk('En riesgo'),
  critical('Crítico');

  final String label;
  const TeamStatus(this.label);

  static const enObjetivo = onTarget;
  static const enRiesgo = atRisk;
  static const critico = critical;
}

typedef EstadoEquipo = TeamStatus;
