import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';

extension OrgStructureLabels on OrgStructure {
  static const notInPayroll = 'No figura en la nómina';

  /// Lo que lidera un usuario según su rol: toda la empresa, o los nombres
  /// de las áreas o los equipos asignados. `null` para un rol desconocido.
  String? leads({required UserRole? role, required String email}) {
    const service = OrgStructureService();
    switch (role) {
      case null:
        return null;
      case UserRole.admin || UserRole.academy:
        return 'Toda la empresa';
      case UserRole.areaLead:
        final areas = service.ledAreasBy(this, email);
        return areas.isEmpty
            ? 'Sin áreas asignadas'
            : areas.map((area) => area.name).join(', ');
      case UserRole.teamLead:
        final teams = service.teamsLedBy(this, email);
        return teams.isEmpty
            ? 'Sin equipos asignados'
            : teams.map((led) => led.team.name).join(', ');
    }
  }

  /// Equipo y área a los que pertenece alguien según su fila de la nómina,
  /// para mostrar junto a lo que lidera (que es una asignación aparte).
  static String membership(Employee? employee) {
    if (employee == null) return notInPayroll;
    final team = employee.team.trim();
    final area = employee.area.trim();
    final text = [
      team.isEmpty ? 'Sin equipo' : team,
      if (area.isNotEmpty) area,
    ].join(' · ');
    return employee.isActive ? text : '$text (baja en la nómina)';
  }

  /// Líderes para mostrar: el nombre de la nómina si el email coincide con el
  /// de algún empleado visible, y si no el email.
  static String leadersLabel(
    Iterable<String> emails,
    Map<String, String> nameByEmail,
  ) {
    final names =
        emails
            .map(
              (email) =>
                  nameByEmail[normalizeLoose(email)] ?? normalizeLoose(email),
            )
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.join(', ');
  }
}
