/// An area of `public.areas`. It comes from the payroll import: its name is
/// the Sector as it came in the spreadsheet, and the app does not edit it.
class Area {
  final String id;
  final String name;
  final Set<String> leaders;

  const Area({required this.id, required this.name, this.leaders = const {}});

  Area copyWith({String? id, String? name, Set<String>? leaders}) => Area(
    id: id ?? this.id,
    name: name ?? this.name,
    leaders: leaders ?? this.leaders,
  );
}

/// A team of `public.equipos`. It belongs to an area and, like it, comes
/// from the payroll import.
class Team {
  final String id;
  final String areaId;
  final String name;
  final Set<String> leaders;

  const Team({
    required this.id,
    required this.areaId,
    required this.name,
    this.leaders = const {},
  });

  Team copyWith({
    String? id,
    String? areaId,
    String? name,
    Set<String>? leaders,
  }) => Team(
    id: id ?? this.id,
    areaId: areaId ?? this.areaId,
    name: name ?? this.name,
    leaders: leaders ?? this.leaders,
  );
}

/// Areas and teams a payroll brings that do not have a row yet.
class PayrollGaps {
  final List<String> areas;
  final List<({String area, String team})> teams;

  const PayrollGaps({this.areas = const [], this.teams = const []});
}

/// Writes that leave exactly the requested leaders active: [end] ends
/// active assignments, [reactivate] reactivates ended ones and [add] creates
/// the ones that never existed. Normalized emails.
class LeaderChanges {
  final Set<String> end;
  final Set<String> reactivate;
  final Set<String> add;

  const LeaderChanges({
    this.end = const {},
    this.reactivate = const {},
    this.add = const {},
  });
}

/// Active employees by area key and by area and team key.
class PayrollHeadcount {
  final Map<String, int> byArea;
  final Map<(String, String), int> byTeam;

  const PayrollHeadcount({this.byArea = const {}, this.byTeam = const {}});
}

/// Areas and teams with their leaders. Leader emails come normalized from
/// the repository.
class OrgStructure {
  final List<Area> areas;
  final List<Team> teams;

  const OrgStructure({required this.areas, required this.teams});
}
