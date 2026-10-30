import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';

/// Áreas, equipos y sus líderes. Las áreas y los equipos solo los crea la
/// importación: la app no los renombra ni los borra. Los errores para mostrar
/// se lanzan como [FormatException].
abstract class OrgStructureRepository {
  Future<OrgStructure> getStructure();

  /// Crea las áreas y equipos nuevos de una nómina. Va antes de sincronizar
  /// la nómina, así un fallo acá no deja empleados a medio escribir.
  Future<void> registerMissing(PayrollGaps missing);

  /// Deja exactamente esos emails como líderes del área.
  Future<void> assignLeadersArea(String areaId, Set<String> emails);

  Future<void> assignTeamLeaders(String teamId, Set<String> emails);
}
