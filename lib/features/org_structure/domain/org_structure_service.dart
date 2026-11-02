import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:collection/collection.dart';

/// Crosses the structure with the payroll. An employee joins their area and
/// team by the payroll key (`normalizeLoose`, the same rule as
/// `public.clave_nomina()` in the database), so "RRHH" and "rrhh " are the same
/// area.
class OrgStructureService {
  const OrgStructureService();

  List<Area> sortedAreas(OrgStructure structure) =>
      [...structure.areas]..sort((a, b) => _byName(a.name, b.name));

  List<Team> teamsOf(OrgStructure structure, String areaId) =>
      structure.teams.where((team) => team.areaId == areaId).toList()
        ..sort((a, b) => _byName(a.name, b.name));

  Area? payrollArea(OrgStructure structure, String sector) {
    final key = normalizeLoose(sector);
    return structure.areas.lastWhereOrNull(
      (area) => normalizeLoose(area.name) == key,
    );
  }

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

  /// Teams led by that email, sorted by area and name.
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

  /// What importing [employees] has to create: the areas and teams whose key
  /// does not exist yet, with the text of the first employee that brings them.
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

  /// How to go from an area's or team's assignments to [desired]. [active]
  /// are the emails with an active assignment and [ended] the ended ones,
  /// normalized; [desired] is normalized and loses the blank ones.
  LeaderChanges leaderChanges({
    required Set<String> active,
    required Set<String> ended,
    required Set<String> desired,
  }) {
    final wanted = desired
        .where((email) => email.trim().isNotEmpty)
        .map(normalizeLoose)
        .toSet();
    final missing = wanted.difference(active);
    return LeaderChanges(
      end: active.difference(wanted),
      reactivate: missing.intersection(ended),
      add: missing.difference(ended),
    );
  }

  PayrollHeadcount activeHeadcount(Iterable<Employee> employees) {
    final active = employees.where((employee) => employee.isActive).toList();
    return PayrollHeadcount(
      byArea: groupBy(
        active,
        (employee) => normalizeLoose(employee.area),
      ).map((key, members) => MapEntry(key, members.length)),
      byTeam: groupBy(
        active,
        (employee) =>
            (normalizeLoose(employee.area), normalizeLoose(employee.team)),
      ).map((key, members) => MapEntry(key, members.length)),
    );
  }

  int areaHeadcount(PayrollHeadcount headcount, Area area) =>
      headcount.byArea[normalizeLoose(area.name)] ?? 0;

  int teamHeadcount(PayrollHeadcount headcount, Area area, Team team) =>
      headcount.byTeam[(
        normalizeLoose(area.name),
        normalizeLoose(team.name),
      )] ??
      0;

  /// Areas whose name, or one of their teams' names, contains [query]. All of
  /// them without text.
  List<Area> areasMatching(OrgStructure structure, String query) {
    final searched = normalizeLoose(query);
    if (searched.isEmpty) return sortedAreas(structure);
    return sortedAreas(structure)
        .where(
          (area) =>
              normalizeLoose(area.name).contains(searched) ||
              teamsOf(
                structure,
                area.id,
              ).any((team) => normalizeLoose(team.name).contains(searched)),
        )
        .toList();
  }

  static int _byName(String a, String b) =>
      normalizeLoose(a).compareTo(normalizeLoose(b));
}
