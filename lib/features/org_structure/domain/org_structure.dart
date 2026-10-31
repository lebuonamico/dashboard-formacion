/// Área de `public.areas`. Sale de la importación de nómina: su nombre es el
/// Sector tal como vino en el Excel, y no se edita desde la app.
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

/// Equipo de `public.equipos`. Pertenece a un área y, como ella, sale de la
/// importación de nómina.
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

/// Áreas y equipos que trae una nómina y todavía no tienen fila.
class PayrollGaps {
  final List<String> areas;
  final List<({String area, String team})> teams;

  const PayrollGaps({this.areas = const [], this.teams = const []});
}

/// Colaboradores activos por clave de área y por clave de área y equipo.
class PayrollHeadcount {
  final Map<String, int> byArea;
  final Map<(String, String), int> byTeam;

  const PayrollHeadcount({this.byArea = const {}, this.byTeam = const {}});
}

/// Áreas y equipos con sus líderes. Los emails de los líderes llegan
/// normalizados desde el repositorio.
class OrgStructure {
  final List<Area> areas;
  final List<Team> teams;

  const OrgStructure({required this.areas, required this.teams});
}
