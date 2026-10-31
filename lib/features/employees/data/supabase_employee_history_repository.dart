import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/features/employees/domain/seniority_parser.dart';

/// Reads `public.empleado_historial`, which a database trigger fills when
/// `empleados` changes.
class SupabaseEmployeeHistoryRepository implements EmployeeHistoryRepository {
  static const _table = 'empleado_historial';
  static const _columns =
      'id,legajo,seniority,sector,equipo_general,gerente,activo,vigente_desde,vigente_hasta';
  static const _pageSize = 500;

  final SupabaseClient _client;

  SupabaseEmployeeHistoryRepository(this._client);

  @override
  Future<List<EmployeeHistoryEntry>> getEmployeeHistory() async {
    final history = <EmployeeHistoryEntry>[];
    for (var offset = 0; ; offset += _pageSize) {
      final rows = await _client
          .from(_table)
          .select(_columns)
          .order('legajo')
          .order('vigente_desde')
          .order('id')
          .range(offset, offset + _pageSize - 1);
      history.addAll(rows.map(_fromRow));
      if (rows.length < _pageSize) return history;
    }
  }

  static EmployeeHistoryEntry _fromRow(Map<String, dynamic> row) {
    if (row['activo'] is! bool ||
        (row['legajo']?.toString().trim() ?? '').isEmpty) {
      throw const FormatException('Estado inválido en empleado_historial.');
    }
    final from = requiredDate(row['vigente_desde']?.toString() ?? '');
    final until = row['vigente_hasta'] == null
        ? null
        : requiredDate(row['vigente_hasta'].toString());
    if (until != null && until.isBefore(from)) {
      throw const FormatException('Intervalo inválido en empleado_historial.');
    }
    final seniorityText = row['seniority']?.toString() ?? '';
    final seniority =
        const SeniorityParser().tryParse(seniorityText) ??
        (throw FormatException(
          'Seniority inválido en empleado_historial: "$seniorityText".',
        ));
    return EmployeeHistoryEntry(
      employeeId: row['legajo'].toString(),
      seniority: seniority,
      area: row['sector']?.toString() ?? '',
      team: row['equipo_general']?.toString() ?? '',
      manager: row['gerente']?.toString() ?? '',
      isActive: row['activo'] as bool,
      validFrom: from,
      validTo: until,
    );
  }
}
