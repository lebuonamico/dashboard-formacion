import 'package:app_finnegans/features/org_structure/data/in_memory_org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/data/org_structure_seed.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:flutter_test/flutter_test.dart';

final _monday = DateTime.utc(2026, 9, 14);
final _friday = DateTime.utc(2026, 9, 18);

InMemoryOrgStructureRepository _repository() => InMemoryOrgStructureRepository(
  areas: [
    const Area(id: '1', name: 'X', leaders: {'ana@finnegans.com'}),
  ],
  teams: [
    const Team(
      id: '1',
      areaId: '1',
      name: 'Y',
      leaders: {'beto@finnegans.com', 'caro@finnegans.com'},
    ),
  ],
);

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

    await repository.assignTeamLeaders('1', {
      ' Lider@Finnegans.com ',
      '  ',
    }, now: _monday);
    await repository.assignAreaLeaders('1', {
      'AREA@finnegans.com',
    }, now: _monday);

    final structure = await repository.getStructure();
    expect(structure.teams.single.leaders, {'lider@finnegans.com'});
    expect(structure.areas.single.leaders, {'area@finnegans.com'});
  });

  test('Los líderes iniciales arrancan con la fecha del seed', () {
    final assignment = _repository().areaLeaderAssignments('1').single;

    expect(assignment.email, 'ana@finnegans.com');
    expect(assignment.assignedAt, seedLeadersAssignedAt);
    expect(assignment.removedAt, isNull);
  });

  test('Quitar un líder le da de baja sin borrar la asignación', () async {
    final repository = _repository();

    await repository.assignTeamLeaders('1', {
      'beto@finnegans.com',
    }, now: _monday);

    final structure = await repository.getStructure();
    expect(structure.teams.single.leaders, {'beto@finnegans.com'});
    final assignments = {
      for (final assignment in repository.teamLeaderAssignments('1'))
        assignment.email: assignment,
    };
    expect(assignments.keys, {'beto@finnegans.com', 'caro@finnegans.com'});
    expect(assignments['caro@finnegans.com']!.removedAt, _monday);
    expect(assignments['beto@finnegans.com']!.removedAt, isNull);
  });

  test('Reasignar reactiva la asignación con su fecha de alta', () async {
    final repository = _repository();
    await repository.assignAreaLeaders('1', const {}, now: _monday);

    await repository.assignAreaLeaders('1', {
      'Ana@finnegans.com',
    }, now: _friday);

    final assignment = repository.areaLeaderAssignments('1').single;
    expect(assignment.removedAt, isNull);
    expect(assignment.assignedAt, seedLeadersAssignedAt);
    final structure = await repository.getStructure();
    expect(structure.areas.single.leaders, {'ana@finnegans.com'});
  });

  test('Un líder nuevo entra con la fecha de la asignación', () async {
    final repository = _repository();

    await repository.assignAreaLeaders('1', {
      'ana@finnegans.com',
      'dani@finnegans.com',
    }, now: _friday);

    final added = repository
        .areaLeaderAssignments('1')
        .singleWhere((assignment) => assignment.email == 'dani@finnegans.com');
    expect(added.assignedAt, _friday);
    expect(added.removedAt, isNull);
    expect(repository.areaLeaderAssignments('1'), hasLength(2));
  });

  test('Un área o equipo nuevo de la nómina admite líderes', () async {
    final repository = _repository();
    await repository.registerMissing(
      const PayrollGaps(
        areas: ['RRHH'],
        teams: [(area: 'RRHH', team: 'Selección')],
      ),
    );

    await repository.assignTeamLeaders('2', {
      'eva@finnegans.com',
    }, now: _monday);

    final structure = await repository.getStructure();
    expect(structure.teams.last.name, 'Selección');
    expect(structure.teams.last.leaders, {'eva@finnegans.com'});
  });

  test('Asignar en un área o equipo inexistente es un error', () async {
    final repository = _repository();

    await expectLater(
      repository.assignAreaLeaders('9', {'ana@finnegans.com'}, now: _monday),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      repository.assignTeamLeaders('9', {'ana@finnegans.com'}, now: _monday),
      throwsA(isA<FormatException>()),
    );
  });
}
