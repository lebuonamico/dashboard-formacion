import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';

abstract class EmployeesRepository {
  Future<List<Employee>> getEmployees({
    String? employeeId,
    String? team,
    String? sector,
  });
  Future<void> replaceEmployees(List<Employee> employees);
  Future<void> resetToMock();
}

extension EmployeesUpsert on EmployeesRepository {
  Future<UpsertResult> syncSnapshotWithResult(List<Employee> items) async {
    if (items.isEmpty || items.any((item) => item.employeeId.trim().isEmpty)) {
      throw const FormatException(
        'La foto de Nómina está vacía o tiene claves inválidas.',
      );
    }
    if (this is SnapshotRepository<Employee>) {
      return (this as SnapshotRepository<Employee>).syncSnapshotWithResult(
        items,
      );
    }
    final present = items.map((item) => item.employeeId).toSet();
    final changes = [
      for (final item in items) item.copyWith(active: true),
      for (final item in await getEmployees())
        if (item.isActive && !present.contains(item.employeeId))
          item.copyWith(active: false),
    ];
    final result = await upsertEmployeesWithResult(changes);
    return UpsertResult(
      processedRecords: items.length,
      inserted: result.inserted,
      updated: result.updated,
    );
  }

  Future<UpsertResult> upsertEmployeesWithResult(List<Employee> items) async {
    if (items.isEmpty) return UpsertResult.empty;
    if (this is CountedUpsertRepository<Employee>) {
      return (this as CountedUpsertRepository<Employee>).upsertWithResult(
        items,
      );
    }
    await upsertEmployees(items);
    return UpsertResult(processedRecords: items.length);
  }

  Future<void> upsertEmployees(List<Employee> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<Employee>) {
      await (this as UpsertRepository<Employee>).upsert(items);
      return;
    }
    final merged = <String, Employee>{};
    for (final item in [...await getEmployees(), ...items]) {
      merged[item.employeeId] = item;
    }
    await replaceEmployees(merged.values.toList());
  }
}
