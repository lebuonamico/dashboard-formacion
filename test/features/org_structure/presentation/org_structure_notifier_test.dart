import 'dart:async';

import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStructure implements OrgStructureRepository {
  OrgStructure structure = const OrgStructure(
    areas: [Area(id: '1', name: 'SERVICIOS')],
    teams: [Team(id: '10', areaId: '1', name: 'IMPLEMENTACIONES')],
  );
  Object? error;
  Completer<void>? gate;

  @override
  Future<OrgStructure> getStructure() async => structure;

  @override
  Future<void> registerMissing(PayrollGaps missing) async {}

  @override
  Future<void> assignLeadersArea(String areaId, Set<String> emails) async {
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    structure = OrgStructure(
      areas: [
        for (final area in structure.areas)
          area.id == areaId
              ? Area(id: area.id, name: area.name, leaders: emails)
              : area,
      ],
      teams: structure.teams,
    );
  }

  @override
  Future<void> assignTeamLeaders(String teamId, Set<String> emails) async {
    await gate?.future;
    structure = OrgStructure(
      areas: structure.areas,
      teams: [
        for (final team in structure.teams)
          team.id == teamId ? team.copyWith(leaders: emails) : team,
      ],
    );
  }
}

Future<(ProviderContainer, _FakeStructure)> _setUp() async {
  final repository = _FakeStructure();
  final container = ProviderContainer(
    overrides: [orgStructureRepositoryProvider.overrideWithValue(repository)],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  container.listen(orgStructureProvider, (_, _) {});
  await container.read(orgStructureNotifierProvider.future);
  return (container, repository);
}

OrgStructureState _state(ProviderContainer container) =>
    container.read(orgStructureNotifierProvider).requireValue;

void main() {
  test('Asignar líderes de equipo guarda y recarga la estructura', () async {
    final (container, _) = await _setUp();

    await container
        .read(orgStructureNotifierProvider.notifier)
        .assignTeamLeaders('10', {'lider@finnegans.com'});

    expect(_state(container).structure.teams.single.leaders, {
      'lider@finnegans.com',
    });
    expect(_state(container).isSaving, isFalse);
    // selectAsync hands the new value to its dependents a microtask later.
    await Future<void>.delayed(Duration.zero);
    final structure = await container.read(orgStructureProvider.future);
    expect(structure.teams.single.leaders, {'lider@finnegans.com'});
  });

  test('Un error se relanza y la estructura queda como estaba', () async {
    final (container, repository) = await _setUp();
    repository.error = const FormatException('Sin permiso.');
    final before = _state(container).structure;

    await expectLater(
      container.read(orgStructureNotifierProvider.notifier).assignAreaLeaders(
        '1',
        {'area@finnegans.com'},
      ),
      throwsA(isA<FormatException>()),
    );

    expect(_state(container).structure, same(before));
    expect(_state(container).isSaving, isFalse);
  });

  test('Mientras guarda queda en curso e ignora otra asignación', () async {
    final (container, repository) = await _setUp();
    final gate = repository.gate = Completer<void>();
    final notifier = container.read(orgStructureNotifierProvider.notifier);

    final assigning = notifier.assignAreaLeaders('1', {'area@finnegans.com'});
    expect(_state(container).isSaving, isTrue);

    await notifier.assignTeamLeaders('10', {'lider@finnegans.com'});

    gate.complete();
    await assigning;
    expect(_state(container).isSaving, isFalse);
    expect(_state(container).structure.areas.single.leaders, {
      'area@finnegans.com',
    });
    expect(_state(container).structure.teams.single.leaders, isEmpty);
  });
}
