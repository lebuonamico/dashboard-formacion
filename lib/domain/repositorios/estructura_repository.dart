import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';

/// Áreas, equipos y sus líderes. Las áreas y los equipos solo los crea la
/// importación: la app no los renombra ni los borra. Los errores para mostrar
/// se lanzan como [FormatException].
abstract class EstructuraRepository {
  Future<EstructuraOrganizacional> getEstructura();

  /// Crea las áreas y equipos nuevos de una nómina. Va antes de sincronizar
  /// la nómina, así un fallo acá no deja empleados a medio escribir.
  Future<void> registrarFaltantes(FaltantesNomina faltantes);

  /// Deja exactamente esos emails como líderes del área.
  Future<void> asignarLideresArea(String areaId, Set<String> emails);

  Future<void> asignarLideresEquipo(String equipoId, Set<String> emails);
}
