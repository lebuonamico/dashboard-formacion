import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/cursada.dart';

abstract class FormacionRepository {
  Future<List<Empleado>> getEmpleados();
  Future<List<Curso>> getCursos();
  Future<List<Cursada>> getCursadas();
}