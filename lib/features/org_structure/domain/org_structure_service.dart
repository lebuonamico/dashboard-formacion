import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:collection/collection.dart';

/// Cruza la estructura con la nómina. El empleado se une con su área y su
/// equipo por la clave de nómina (`normalizeLoose`, la misma regla que
/// `public.clave_nomina()` en la base), así "RRHH" y "rrhh " son la misma área.
class OrgStructureService {
  const OrgStructureService();

  List<Area> sortedAreas(OrgStructure structure) =>
      [...structure.areas]..sort((a, b) => _byName(a.name, b.name));

  List<Team> teamsOf(OrgStructure structure, String areaId) =>
      structure.teams.where((team) => team.areaId == areaId).toList()
        ..sort((a, b) => _byName(a.name, b.name));

  /// Área por el Sector de la nómina.
  Area? payrollArea(OrgStructure structure, String sector) {
    final key = normalizeLoose(sector);
    return structure.areas.lastWhereOrNull(
      (area) => normalizeLoose(area.name) == key,
    );
  }

  /// Equipo por el Sector y el Equipo de la nómina.
  Team? payrollTeam(OrgStructure structure, String sector, String team) {
    final area = payrollArea(structure, sector);
    if (area == null) return null;
    final key = normalizeLoose(team);
    return structure.teams.lastWhereOrNull(
      (candidate) =>
          candidate.areaId == area.id && normalizeLoose(candidate.name) == key,
    );
  }

  Set<String> areaLeaders(OrgStructure structure, String sector) =>
      payrollArea(structure, sector)?.leaders ?? const {};

  Set<String> teamLeaders(OrgStructure structure, String sector, String team) =>
      payrollTeam(structure, sector, team)?.leaders ?? const {};

  List<Area> ledAreasBy(OrgStructure structure, String email) {
    final normalized = normalizeLoose(email);
    return sortedAreas(
      structure,
    ).where((area) => area.leaders.contains(normalized)).toList();
  }

  /// Equipos que lidera ese email, ordenados por área y por nombre.
  List<({Area area, Team team})> teamsLedBy(
    OrgStructure structure,
    String email,
  ) {
    final normalized = normalizeLoose(email);
    return [
      for (final area in sortedAreas(structure))
        for (final team in teamsOf(structure, area.id))
          if (team.leaders.contains(normalized)) (area: area, team: team),
    ];
  }

  /// Lo que la importación de [employees] tiene que crear: las áreas y los
  /// equipos cuya clave todavía no existe, con el texto del primer empleado
  /// que los trae.
  PayrollGaps missingFromPayroll(
    OrgStructure structure,
    Iterable<Employee> employees,
  ) {
    final rows = employees
        .map(
          (employee) =>
              (area: employee.area.trim(), team: employee.team.trim()),
        )
        .where((row) => normalizeLoose(row.area).isNotEmpty)
        .toList();
    final newAreas = groupBy(
      rows.where((row) => payrollArea(structure, row.area) == null),
      (row) => normalizeLoose(row.area),
    );
    final newTeams = groupBy(
      rows.where(
        (row) =>
            normalizeLoose(row.team).isNotEmpty &&
            payrollTeam(structure, row.area, row.team) == null,
      ),
      (row) => (normalizeLoose(row.area), normalizeLoose(row.team)),
    );

    return PayrollGaps(
      areas: newAreas.values.map((rows) => rows.first.area).toList(),
      teams: newTeams.values.map((rows) {
        final first = rows.first;
        final area =
            payrollArea(structure, first.area)?.name ??
            newAreas[normalizeLoose(first.area)]!.first.area;
        return (area: area, team: first.team);
      }).toList(),
    );
  }

  bool isEmpty(PayrollGaps gaps) => gaps.areas.isEmpty && gaps.teams.isEmpty;

  static int _byName(String a, String b) =>
      normalizeLoose(a).compareTo(normalizeLoose(b));
}
