import 'package:app_finnegans/domain/modelos/curso.dart';

abstract class CursosRepository {
  Future<List<Curso>> getCursos();
  Future<void> replaceCursos(List<Curso> cursos);
  Future<void> resetToMock();
}
