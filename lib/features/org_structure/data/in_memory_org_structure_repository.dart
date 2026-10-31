import 'dart:math';

import 'package:app_finnegans/features/org_structure/data/org_structure_seed.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';

class InMemoryOrgStructureRepository implements OrgStructureRepository {
  final List<Area> _areas;
  final List<Team> _teams;

  InMemoryOrgStructureRepository({List<Area>? areas, List<Team>? teams})
    : _areas = [...areas ?? areasSeed],
      _teams = [...teams ?? teamsSeed];

  @override
  Future<OrgStructure> getStructure() async =>
      OrgStructure(areas: [..._areas], teams: [..._teams]);

  @override
  Future<void> registerMissing(PayrollGaps missing) async {
    _areas.addAll(
      missing.areas.map(
        (name) => Area(id: _nextId(_areas.map((area) => area.id)), name: name),
      ),
    );
    final areaIdByKey = {for (final area in _areas) area.payrollKey: area.id};
    for (final gap in missing.teams) {
      final areaId =
          areaIdByKey[OrgStructure.payrollKey(gap.area)] ??
          (throw FormatException(
            'No se encontró el área "${gap.area}" para crear el '
            'equipo "${gap.team}".',
          ));
      _teams.add(
        Team(
          id: _nextId(_teams.map((team) => team.id)),
          areaId: areaId,
          name: gap.team,
        ),
      );
    }
  }

  @override
  Future<void> assignLeadersArea(String areaId, Set<String> emails) async {
    final index = _indexOf(_areas.map((area) => area.id), areaId);
    final area = _areas[index];
    _areas[index] = Area(
      id: area.id,
      name: area.name,
      leaders: _withoutBlanks(emails),
    );
  }

  @override
  Future<void> assignTeamLeaders(String teamId, Set<String> emails) async {
    final index = _indexOf(_teams.map((team) => team.id), teamId);
    final team = _teams[index];
    _teams[index] = Team(
      id: team.id,
      areaId: team.areaId,
      name: team.name,
      leaders: _withoutBlanks(emails),
    );
  }

  static int _indexOf(Iterable<String> ids, String id) {
    final index = ids.toList().indexOf(id);
    if (index == -1) {
      throw const FormatException(
        'No se pudo guardar el cambio: el área o el equipo ya no existe.',
      );
    }
    return index;
  }

  static Set<String> _withoutBlanks(Set<String> emails) =>
      emails.where((email) => email.trim().isNotEmpty).toSet();

  static String _nextId(Iterable<String> ids) =>
      '${ids.map(int.tryParse).nonNulls.fold(0, max) + 1}';
}
