import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';

abstract class CursosRepository {
  Future<List<Curso>> getCursos({String? id, String? nombre});
  Future<void> replaceCursos(List<Curso> cursos);
  Future<void> resetToMock();
}

extension CursosUpsert on CursosRepository {
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
