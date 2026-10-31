import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';

final areasSeed = [
  const Area(
    id: '1',
    name: 'Desarrollo',
    leaders: {'valeria.rios@finnegans-demo.com'},
  ),
  const Area(id: '2', name: 'Calidad'),
];

final teamsSeed = [
  const Team(
    id: '1',
    areaId: '1',
    name: 'Core ERP Backend',
    leaders: {'lucas.gomez@finnegans-demo.com'},
  ),
  const Team(id: '2', areaId: '1', name: 'Frontend Arquitectura & UI'),
  const Team(
    id: '3',
    areaId: '2',
    name: 'QA Automation',
    leaders: {'sebastian.gonzalez@finnegans-demo.com'},
  ),
];
