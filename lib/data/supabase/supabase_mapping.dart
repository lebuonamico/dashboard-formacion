/// Physical names and conflict constraints are supplied after SQL design.
/// No table names, historical keys or deletion policy are assumed here.
class SupabaseTableMapping {
  final String table;
  final Map<String, String> columns;
  final List<String> conflictFields;

  SupabaseTableMapping({
    required this.table,
    required Map<String, String> columns,
    required List<String> conflictFields,
  }) : columns = Map.unmodifiable(columns),
       conflictFields = List.unmodifiable(conflictFields) {
    if (table.trim().isEmpty ||
        columns.isEmpty ||
        conflictFields.isEmpty ||
        columns.values.any((c) => c.trim().isEmpty) ||
        columns.values.toSet().length != columns.length) {
      throw ArgumentError('Mapeo Supabase incompleto o ambiguo.');
    }
    for (final field in conflictFields) {
      column(field);
    }
  }

  String column(String field) =>
      columns[field] ??
      (throw StateError('Falta el mapeo del campo $field en $table.'));

  String get onConflict => conflictFields.map(column).join(',');

  Map<String, dynamic> encode(Map<String, dynamic> source) => {
    for (final entry in columns.entries)
      if (source.containsKey(entry.key)) entry.value: source[entry.key],
  };

  Map<String, dynamic> decode(Map<String, dynamic> row) => {
    for (final entry in columns.entries) entry.key: row[entry.value],
  };

  void requireFields(Iterable<String> fields) {
    for (final field in fields) {
      column(field);
    }
  }
}

class SupabaseMappings {
  final SupabaseTableMapping empleados;
  final SupabaseTableMapping cursos;
  final SupabaseTableMapping horas;
  final SupabaseTableMapping finalizaciones;

  const SupabaseMappings({
    required this.empleados,
    required this.cursos,
    required this.horas,
    required this.finalizaciones,
  });
}
