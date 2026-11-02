enum AssistantModule {
  dashboard,
  areas,
  teams,
  teamDetail,
  people,
  courses,
  settings,
  others,
}

/// The navigation parameters are only used to look entities up locally. The
/// URL, employee IDs and arbitrary parameters are never serialized.
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
