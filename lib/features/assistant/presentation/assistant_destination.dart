import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';

/// The screen the question is asked from, read from the app routes.
AssistantDestination assistantDestinationFor(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.firstOrNull == 'areas') {
    final isTeam = segments.length >= 4 && segments[2] == 'equipos';
    return AssistantDestination(
      isTeam ? AssistantModule.teamDetail : AssistantModule.areas,
      area: segments.length > 1 ? segments[1] : null,
      team: segments.length >= 4 ? segments[3] : null,
    );
  }
  return AssistantDestination(
    switch (segments.firstOrNull) {
      'dashboard' => AssistantModule.dashboard,
      'equipos' => AssistantModule.teams,
      'empleados' => AssistantModule.people,
      'cursos' => AssistantModule.courses,
      'configuracion' => AssistantModule.settings,
      _ => AssistantModule.others,
    },
    employeeId: segments.firstOrNull == 'empleados' && segments.length > 1
        ? segments[1]
        : null,
  );
}
