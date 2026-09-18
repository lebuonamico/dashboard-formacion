import 'package:app_finnegans/domain/modelos/empleado.dart';

abstract class EmpleadosRepository {
  Future<List<Empleado>> getEmpleados();
  Future<void> replaceEmpleados(List<Empleado> empleados);
  Future<void> resetToMock();
}
