import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

final empleadosRepositoryProvider = Provider<EmpleadosRepository>((ref) {
  return LocalEmpleadosRepository();
});

final cursosRepositoryProvider = Provider<CursosRepository>((ref) {
  return LocalCursosRepository();
});

final cargaDeHorasCRMRepositoryProvider = Provider<CargaDeHorasCRMRepository>((
  ref,
) {
  return LocalCargaDeHorasCRMRepository();
});

final cumplimientoServiceProvider = Provider<CumplimientoService>((ref) {
  return CumplimientoService();
});
