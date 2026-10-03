import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';

abstract class EmpleadosRepository {
  Future<List<Empleado>> getEmpleados({
    String? legajo,
    String? equipo,
    String? sector,
  });
  Future<void> replaceEmpleados(List<Empleado> empleados);
  Future<void> resetToMock();
}

extension EmpleadosUpsert on EmpleadosRepository {
  Future<void> upsertEmpleados(List<Empleado> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<Empleado>) {
      await (this as UpsertRepository<Empleado>).upsert(items);
      return;
    }
    final merged = <String, Empleado>{};
    for (final item in [...await getEmpleados(), ...items]) {
      merged[item.legajo] = item;
    }
    await replaceEmpleados(merged.values.toList());
  }
}
