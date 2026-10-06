import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';

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
  Future<ResultadoUpsert> sincronizarFotoVigenteConResultado(
    List<Empleado> items,
  ) async {
    if (items.isEmpty || items.any((item) => item.legajo.trim().isEmpty)) {
      throw const FormatException(
        'La foto de Nómina está vacía o tiene claves inválidas.',
      );
    }
    if (this is FotoVigenteRepository<Empleado>) {
      return (this as FotoVigenteRepository<Empleado>)
          .sincronizarFotoVigenteConResultado(items);
    }
    final presentes = items.map((item) => item.legajo).toSet();
    final cambios = [
      for (final item in items) item.copyWith(activo: true),
      for (final item in await getEmpleados())
        if (item.activo && !presentes.contains(item.legajo))
          item.copyWith(activo: false),
    ];
    final resultado = await upsertEmpleadosConResultado(cambios);
    return ResultadoUpsert(
      registrosProcesados: items.length,
      insertados: resultado.insertados,
      actualizados: resultado.actualizados,
    );
  }

  Future<ResultadoUpsert> upsertEmpleadosConResultado(
    List<Empleado> items,
  ) async {
    if (items.isEmpty) return ResultadoUpsert.empty;
    if (this is CountedUpsertRepository<Empleado>) {
      return (this as CountedUpsertRepository<Empleado>).upsertConResultado(
        items,
      );
    }
    await upsertEmpleados(items);
    return ResultadoUpsert(registrosProcesados: items.length);
  }

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
