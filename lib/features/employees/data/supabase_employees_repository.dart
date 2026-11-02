import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/core/data/supabase_table.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/features/employees/domain/seniority_parser.dart';

/// Writing `empleados` also feeds `empleado_historial` through its trigger.
class SupabaseEmployeesRepository implements EmployeesRepository {
  static final mapping = SupabaseTableMapping(
    table: 'empleados',
    conflictFields: ['employeeId'],
    columns: {
      'employeeId': 'legajo',
      'email': 'correo',
      'firstName': 'nombre',
      'lastName': 'apellido',
      'seniority': 'seniority',
      'area': 'sector',
      'team': 'equipo_general',
      'manager': 'gerente',
      'hireDate': 'fecha_ingreso',
      'isActive': 'activo',
    },
  );

  final SupabaseTable _table;

  SupabaseEmployeesRepository(SupabaseClient client)
    : _table = SupabaseTable(client, mapping);

  @override
  Future<List<Employee>> getEmployees() async => (await _table.read())
      .map(
        (row) => Employee.fromJson({
          ...row,
          'seniority': const SeniorityParser()
              .parse(row['seniority']?.toString() ?? '')
              .name,
        }),
      )
      .toList();

  @override
  Future<UpsertResult> upsert(List<Employee> employees) async {
    final written = await _table.upsert(
      employees.map((employee) => employee.toJson()).toList(),
    );
    return UpsertResult(
      processedRecords: employees.length,
      inserted: written.inserted,
      updated: written.updated,
    );
  }
}
