import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';

/// Área de `public.areas`. Sale de la importación de nómina: su nombre es el
/// Sector tal como vino en el Excel, y no se edita desde la app.
class Area {
  final String id;
  final String name;
  final Set<String> leaders;

  Area({required this.id, required this.name, Set<String> leaders = const {}})
    : leaders = {
        for (final email in leaders) OrgStructure.normalizeEmail(email),
      };

  String get payrollKey => OrgStructure.payrollKey(name);
}

/// Equipo de `public.equipos`. Pertenece a un área y, como ella, sale de la
/// importación de nómina.
class Team {
  final String id;
  final String areaId;
  final String name;
  final Set<String> leaders;

  Team({
    required this.id,
    required this.areaId,
    required this.name,
    Set<String> leaders = const {},
  }) : leaders = {
         for (final email in leaders) OrgStructure.normalizeEmail(email),
       };

  String get payrollKey => OrgStructure.payrollKey(name);
}

/// Áreas y equipos que trae una nómina y todavía no tienen fila.
class PayrollGaps {
  final List<String> areas;
  final List<({String area, String team})> teams;

  const PayrollGaps({this.areas = const [], this.teams = const []});

  bool get empty => areas.isEmpty && teams.isEmpty;
}

/// Áreas, equipos y líderes, con las reglas que los cruzan con la nómina.
///
/// El empleado se une con su área y su equipo por la clave de nómina (el
/// texto del Excel recortado y en minúsculas), así "RRHH" y "rrhh " son la
/// misma área.
class OrgStructure {
  final List<Area> areas;
  final List<Team> teams;

  final Map<String, Area> _areasByKey;
  final Map<(String, String), Team> _teamsByKey;

  OrgStructure({required this.areas, required this.teams})
    : _areasByKey = {for (final area in areas) area.payrollKey: area},
      _teamsByKey = {
        for (final team in teams) (team.areaId, team.payrollKey): team,
      };

  /// Misma regla que `public.clave_nomina()` en la base.
  static String payrollKey(String text) => text.trim().toLowerCase();

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static int _byName(String a, String b) =>
      payrollKey(a).compareTo(payrollKey(b));

  /// Áreas ordenadas por nombre.
  List<Area> get sortedAreas =>
      [...areas]..sort((a, b) => _byName(a.name, b.name));

  /// Equipos de un área, ordenados por nombre.
  List<Team> teamsOf(String areaId) =>
      teams.where((team) => team.areaId == areaId).toList()
        ..sort((a, b) => _byName(a.name, b.name));

  /// Área por el Sector de la nómina.
  Area? payrollArea(String sector) => _areasByKey[payrollKey(sector)];

  /// Equipo por el Sector y el Equipo de la nómina.
  Team? payrollTeam(String sector, String team) {
    final area = payrollArea(sector);
    if (area == null) return null;
    return _teamsByKey[(area.id, payrollKey(team))];
  }

  Set<String> areaLeaders(String sector) =>
      payrollArea(sector)?.leaders ?? const {};

  Set<String> teamLeaders(String sector, String team) =>
      payrollTeam(sector, team)?.leaders ?? const {};

  List<Area> ledAreasBy(String email) {
    final normalized = normalizeEmail(email);
    return sortedAreas
        .where((area) => area.leaders.contains(normalized))
        .toList();
  }

  /// Equipos que lidera ese email, ordenados por área y por nombre.
  List<({Area area, Team team})> teamsLedBy(String email) {
    final normalized = normalizeEmail(email);
    return [
      for (final area in sortedAreas)
        for (final team in teamsOf(area.id))
          if (team.leaders.contains(normalized)) (area: area, team: team),
    ];
  }

  /// Lo que la importación de [employees] tiene que crear: las áreas y los
  /// equipos cuya clave todavía no existe, con el texto del primer empleado
  /// que los trae.
  PayrollGaps missingFromPayroll(Iterable<Employee> employees) {
    final newAreas = <String, String>{};
    final newTeams = <(String, String), ({String area, String team})>{};

    for (final employee in employees) {
      final sector = employee.area.trim();
      final keyArea = payrollKey(sector);
      if (keyArea.isEmpty) continue;
      final area = _areasByKey[keyArea];
      if (area == null) newAreas.putIfAbsent(keyArea, () => sector);

      final team = employee.team.trim();
      final teamKey = payrollKey(team);
      if (teamKey.isEmpty) continue;
      if (area != null && _teamsByKey.containsKey((area.id, teamKey))) {
        continue;
      }
      newTeams.putIfAbsent((
        keyArea,
        teamKey,
      ), () => (area: area?.name ?? newAreas[keyArea]!, team: team));
    }

    return PayrollGaps(
      areas: newAreas.values.toList(),
      teams: newTeams.values.toList(),
    );
  }

  /// Lo que lidera un usuario según su rol: toda la empresa, o los nombres
  /// de las áreas o los equipos asignados. `null` para un rol desconocido.
  String? leads({required UserRole? role, required String email}) {
    switch (role) {
      case null:
        return null;
      case UserRole.admin || UserRole.academy:
        return 'Toda la empresa';
      case UserRole.areaLead:
        final areas = ledAreasBy(email);
        return areas.isEmpty
            ? 'Sin áreas asignadas'
            : areas.map((area) => area.name).join(', ');
      case UserRole.teamLead:
        final teams = teamsLedBy(email);
        return teams.isEmpty
            ? 'Sin equipos asignados'
            : teams.map((led) => led.team.name).join(', ');
    }
  }

  static const notInPayroll = 'No figura en la nómina';

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
    final names = [
      for (final email in emails)
        nameByEmail[normalizeEmail(email)] ?? normalizeEmail(email),
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.join(', ');
  }
}
