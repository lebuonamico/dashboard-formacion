import 'dart:math';

import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/org_structure/data/leader_assignment.dart';
import 'package:app_finnegans/features/org_structure/data/org_structure_seed.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
import 'package:flutter/foundation.dart';

class InMemoryOrgStructureRepository implements OrgStructureRepository {
  static const _service = OrgStructureService();

  final List<Area> _areas;
  final List<Team> _teams;
  final Map<String, List<LeaderAssignment>> _areaLeaders;
  final Map<String, List<LeaderAssignment>> _teamLeaders;

  InMemoryOrgStructureRepository({List<Area>? areas, List<Team>? teams})
    : this._(areas ?? areasSeed, teams ?? teamsSeed);

  InMemoryOrgStructureRepository._(List<Area> areas, List<Team> teams)
    : _areas = [for (final area in areas) area.copyWith(leaders: const {})],
      _teams = [for (final team in teams) team.copyWith(leaders: const {})],
      _areaLeaders = {
        for (final area in areas) area.id: _seedAssignments(area.leaders),
      },
      _teamLeaders = {
        for (final team in teams) team.id: _seedAssignments(team.leaders),
      };

  @visibleForTesting
  List<LeaderAssignment> areaLeaderAssignments(String areaId) =>
      List.unmodifiable(_areaLeaders[areaId] ?? const <LeaderAssignment>[]);

  @visibleForTesting
  List<LeaderAssignment> teamLeaderAssignments(String teamId) =>
      List.unmodifiable(_teamLeaders[teamId] ?? const <LeaderAssignment>[]);

  @override
  Future<OrgStructure> getStructure() async => OrgStructure(
    areas: _areas
        .map(
          (area) =>
              area.copyWith(leaders: _activeEmails(_areaLeaders[area.id])),
        )
        .toList(),
    teams: _teams
        .map(
          (team) =>
              team.copyWith(leaders: _activeEmails(_teamLeaders[team.id])),
        )
        .toList(),
  );

  @override
  Future<void> registerMissing(PayrollGaps missing) async {
    _areas.addAll(
      missing.areas.map(
        (name) => Area(id: _nextId(_areas.map((area) => area.id)), name: name),
      ),
    );
    final areaIdByKey = {
      for (final area in _areas) normalizeLoose(area.name): area.id,
    };
    for (final gap in missing.teams) {
      final areaId =
          areaIdByKey[normalizeLoose(gap.area)] ??
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
  Future<void> assignAreaLeaders(
    String areaId,
    Set<String> emails, {
    required DateTime now,
  }) async {
    _requireId(_areas.map((area) => area.id), areaId);
    _assign(_areaLeaders, areaId, emails, now);
  }

  @override
  Future<void> assignTeamLeaders(
    String teamId,
    Set<String> emails, {
    required DateTime now,
  }) async {
    _requireId(_teams.map((team) => team.id), teamId);
    _assign(_teamLeaders, teamId, emails, now);
  }

  static void _assign(
    Map<String, List<LeaderAssignment>> assignmentsById,
    String id,
    Set<String> emails,
    DateTime now,
  ) {
    final current = assignmentsById[id] ?? const <LeaderAssignment>[];
    final changes = _service.leaderChanges(
      active: _activeEmails(current),
      ended: current
          .where((assignment) => assignment.removedAt != null)
          .map((assignment) => assignment.email)
          .toSet(),
      desired: emails,
    );
    assignmentsById[id] = [
      ...current.map(
        (assignment) => changes.end.contains(assignment.email)
            ? assignment.copyWith(removedAt: now)
            : changes.reactivate.contains(assignment.email)
            ? assignment.copyWith(removedAt: null)
            : assignment,
      ),
      ...changes.add.map(
        (email) => LeaderAssignment(email: email, assignedAt: now),
      ),
    ];
  }

  static Set<String> _activeEmails(List<LeaderAssignment>? assignments) =>
      (assignments ?? const <LeaderAssignment>[])
          .where((assignment) => assignment.removedAt == null)
          .map((assignment) => assignment.email)
          .toSet();

  static List<LeaderAssignment> _seedAssignments(Set<String> emails) => emails
      .where((email) => email.trim().isNotEmpty)
      .map(normalizeLoose)
      .toSet()
      .map(
        (email) =>
            LeaderAssignment(email: email, assignedAt: seedLeadersAssignedAt),
      )
      .toList();

  static void _requireId(Iterable<String> ids, String id) {
    if (!ids.contains(id)) {
      throw const FormatException(
        'No se pudo guardar el cambio: el área o el equipo ya no existe.',
      );
    }
  }

  static String _nextId(Iterable<String> ids) =>
      '${ids.map(int.tryParse).nonNulls.fold(0, max) + 1}';
}
