enum TeamStatus {
  onTarget('En objetivo'),
  atRisk('En riesgo'),
  critical('Crítico');

  final String label;
  const TeamStatus(this.label);
}
