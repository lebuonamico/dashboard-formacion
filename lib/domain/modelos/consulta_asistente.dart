enum AssistantModule {
  dashboard('Dashboard'),
  areas('Áreas'),
  teams('Equipos'),
  teamDetail('Detalle de equipo'),
  people('Personas'),
  courses('Cursos'),
  settings('Configuración'),
  others('Ayuda general');

  final String label;
  const AssistantModule(this.label);
}

/// Los parámetros de navegación se usan para buscar entidades localmente.
/// Nunca se serializan la URL, los legajos ni parámetros arbitrarios.
class AssistantDestination {
  final AssistantModule module;
  final String? area;
  final String? team;
  final String? employeeId;
  const AssistantDestination(
    this.module, {
    this.area,
    this.team,
    this.employeeId,
  });

  factory AssistantDestination.fromUri(Uri uri) {
    final p = uri.pathSegments;
    if (p.firstOrNull == 'areas') {
      return AssistantDestination(
        p.length >= 4 && p[2] == 'equipos'
            ? AssistantModule.teamDetail
            : AssistantModule.areas,
        area: p.length > 1 ? p[1] : null,
        team: p.length >= 4 ? p[3] : null,
      );
    }
    return AssistantDestination(switch (p.firstOrNull) {
      'dashboard' => AssistantModule.dashboard,
      'equipos' => AssistantModule.teams,
      'empleados' => AssistantModule.people,
      'cursos' => AssistantModule.courses,
      'configuracion' => AssistantModule.settings,
      _ => AssistantModule.others,
    }, employeeId: p.firstOrNull == 'empleados' && p.length > 1 ? p[1] : null);
  }
}

class AssistantPeriod {
  final int year;
  final int month;
  final bool annual;
  const AssistantPeriod({
    required this.year,
    required this.month,
    this.annual = false,
  });
  Map<String, Object> toJson() => {
    'anio': year,
    if (!annual) 'mes': month,
    'alcance': annual ? 'anual' : 'mensual',
  };
  String get label => annual ? 'Año $year' : '$month/$year';
}

enum AssistantTopic {
  general,
  areas,
  teams,
  person,
  courses,
  import,
  conceptual,
}

class AssistantQuery {
  final AssistantDestination destination;
  final AssistantTopic theme;
  final String question;
  final List<AssistantPeriod> periods;
  final List<String> notes;
  final bool evolution;
  final bool accumulated;
  const AssistantQuery({
    required this.destination,
    required this.theme,
    required this.question,
    required this.periods,
    this.notes = const [],
    this.evolution = false,
    this.accumulated = false,
  });
}
