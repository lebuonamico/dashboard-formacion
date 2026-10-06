import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';

abstract class CursosRepository {
  Future<List<Curso>> getCursos({String? id, String? nombre});
  Future<void> replaceCursos(List<Curso> cursos);
  Future<void> resetToMock();
}

extension CursosUpsert on CursosRepository {
  Future<ResultadoUpsert> sincronizarFotoVigenteConResultado(
    List<Curso> items,
  ) async {
    if (items.isEmpty || items.any((item) => item.id.trim().isEmpty)) {
      throw const FormatException(
        'La foto de Cursos está vacía o tiene claves inválidas.',
      );
    }
    if (this is FotoVigenteRepository<Curso>) {
      return (this as FotoVigenteRepository<Curso>)
          .sincronizarFotoVigenteConResultado(items);
    }
    final presentes = items.map((item) => item.id).toSet();
    final cambios = [
      for (final item in items) item.copyWith(activo: true),
      for (final item in await getCursos())
        if (item.activo && !presentes.contains(item.id))
          item.copyWith(activo: false),
    ];
    final resultado = await upsertCursosConResultado(cambios);
    return ResultadoUpsert(
      registrosProcesados: items.length,
      insertados: resultado.insertados,
      actualizados: resultado.actualizados,
    );
  }

  Future<ResultadoUpsert> upsertCursosConResultado(List<Curso> items) async {
    if (items.isEmpty) return ResultadoUpsert.empty;
    if (this is CountedUpsertRepository<Curso>) {
      return (this as CountedUpsertRepository<Curso>).upsertConResultado(items);
    }
    await upsertCursos(items);
    return ResultadoUpsert(registrosProcesados: items.length);
  }

  Future<void> upsertCursos(List<Curso> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<Curso>) {
      await (this as UpsertRepository<Curso>).upsert(items);
      return;
    }
    final merged = <String, Curso>{};
    for (final item in [...await getCursos(), ...items]) {
      merged[item.id] = item;
    }
    await replaceCursos(merged.values.toList());
  }
}
