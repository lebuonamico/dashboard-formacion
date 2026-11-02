import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';

extension OrgStructureLabels on OrgStructure {
  static const notInPayroll = 'No figura en la nómina';

  /// What a user leads by role: the whole company, or the names of the
  /// assigned areas or teams. `null` for an unknown role.
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

  /// Team and area someone belongs to according to their payroll row, shown
  /// next to what they lead (a separate assignment).
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

  /// Leaders to show: the payroll name if the email matches a visible
  /// employee, otherwise the email.
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
