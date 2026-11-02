const _keep = Object();

/// A row of `area_lideres` / `equipo_lideres` in the in-memory repository.
/// An assignment is never deleted: it ends with [removedAt] and is reactivated
/// by clearing it.
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
