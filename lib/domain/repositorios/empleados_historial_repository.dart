import 'package:app_finnegans/domain/modelos/empleado_historial.dart';

/// Lectura opcional de la infraestructura histórica existente en Supabase.
abstract class EmpleadosHistorialRepository {
  Future<List<EmpleadoHistorial>> getHistorialEmpleados();
}
