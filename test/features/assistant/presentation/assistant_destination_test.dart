import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/presentation/assistant_destination.dart';
import 'package:flutter_test/flutter_test.dart';

(AssistantModule, String?, String?, String?) _destination(String path) {
  final destination = assistantDestinationFor(Uri.parse(path));
  return (
    destination.module,
    destination.area,
    destination.team,
    destination.employeeId,
  );
}

void main() {
  test('cada sección tiene su módulo', () {
    expect(_destination('/dashboard'), (
      AssistantModule.dashboard,
      null,
      null,
      null,
    ));
    expect(_destination('/equipos'), (AssistantModule.teams, null, null, null));
    expect(_destination('/cursos'), (
      AssistantModule.courses,
      null,
      null,
      null,
    ));
    expect(_destination('/configuracion'), (
      AssistantModule.settings,
      null,
      null,
      null,
    ));
    expect(_destination('/cursadas'), (
      AssistantModule.others,
      null,
      null,
      null,
    ));
    expect(_destination('/'), (AssistantModule.others, null, null, null));
  });

  test('áreas, con el área y el equipo de la ruta', () {
    expect(_destination('/areas'), (AssistantModule.areas, null, null, null));
    expect(_destination('/areas/Desarrollo'), (
      AssistantModule.areas,
      'Desarrollo',
      null,
      null,
    ));
    expect(
      _destination(
        '/areas/Desarrollo/equipos/Frontend%20Arquitectura%20%26%20UI',
      ),
      (
        AssistantModule.teamDetail,
        'Desarrollo',
        'Frontend Arquitectura & UI',
        null,
      ),
    );
  });

  test('personas, con el legajo solo en el perfil', () {
    expect(_destination('/empleados'), (
      AssistantModule.people,
      null,
      null,
      null,
    ));
    expect(_destination('/empleados/EMP-005?origen=certificaciones'), (
      AssistantModule.people,
      null,
      null,
      'EMP-005',
    ));
  });
}
