import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/cursada.dart';

abstract class FormacionRepository {
  Future<List<Empleado>> getEmpleados();
  Future<List<Curso>> getCursos();
  Future<List<Cursada>> getCursadas();
  Future<void> replaceData({
    required List<Empleado> empleados,
    required List<Curso> cursos,
    required List<Cursada> cursadas,
  });
  Future<void> resetToMock();
}