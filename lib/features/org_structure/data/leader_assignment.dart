const _keep = Object();

/// Fila de `area_lideres` / `equipo_lideres` en el repositorio en memoria.
/// Una asignación no se borra: termina con [removedAt] y se reactiva
/// limpiándolo.
class LeaderAssignment {
  final String email;
  final DateTime assignedAt;
  final DateTime? removedAt;

  const LeaderAssignment({
    required this.email,
    required this.assignedAt,
    this.removedAt,
  });

  LeaderAssignment copyWith({
    String? email,
    DateTime? assignedAt,
    Object? removedAt = _keep,
  }) => LeaderAssignment(
    email: email ?? this.email,
    assignedAt: assignedAt ?? this.assignedAt,
    removedAt: identical(removedAt, _keep)
        ? this.removedAt
        : removedAt as DateTime?,
  );
}
