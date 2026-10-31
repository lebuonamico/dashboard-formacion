const personFilterDimension = 'Persona / Legajo';
const courseFilterDimension = 'Curso / ID';

String personFilterLabel(String name, String employeeId) {
  final shownName = name.trim().isEmpty ? 'Persona sin nombre' : name.trim();
  final shownId = employeeId.trim().isEmpty
      ? 'Sin legajo'
      : 'Legajo ${employeeId.trim()}';
  return '$shownName — $shownId';
}

String courseFilterLabel(String name, String id) {
  final shownName = name.trim().isEmpty ? 'Curso sin nombre' : name.trim();
  final shownId = id.trim().isEmpty ? 'Sin ID' : 'ID ${id.trim()}';
  return '$shownName — $shownId';
}

String? filterEntitySubtitle(String dimension, String value) =>
    switch (dimension) {
      personFilterDimension => 'Legajo $value',
      courseFilterDimension => 'ID $value',
      _ => null,
    };
