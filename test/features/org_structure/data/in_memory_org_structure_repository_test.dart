import 'package:app_finnegans/features/org_structure/data/in_memory_org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Los emails de líderes se guardan normalizados', () async {
    final repository = InMemoryOrgStructureRepository(
      areas: [
        const Area(id: '1', name: 'X', leaders: {'  Ana@Finnegans.COM '}),
      ],
      teams: [
        const Team(id: '1', areaId: '1', name: 'Y', leaders: {'Beto@X.com'}),
      ],
    );

    final structure = await repository.getStructure();
    expect(structure.areas.single.leaders, {'ana@finnegans.com'});
    expect(structure.teams.single.leaders, {'beto@x.com'});
  });

  test('Asignar líderes normaliza y descarta los vacíos', () async {
    final repository = InMemoryOrgStructureRepository(
      areas: [const Area(id: '1', name: 'X')],
      teams: [const Team(id: '1', areaId: '1', name: 'Y')],
    );

    await repository.assignTeamLeaders('1', {' Lider@Finnegans.com ', '  '});
    await repository.assignLeadersArea('1', {'AREA@finnegans.com'});

    final structure = await repository.getStructure();
    expect(structure.teams.single.leaders, {'lider@finnegans.com'});
    expect(structure.areas.single.leaders, {'area@finnegans.com'});
  });
}
