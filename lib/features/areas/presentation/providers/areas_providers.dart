import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/features/areas/domain/area_summary.dart';
import 'package:app_finnegans/features/areas/domain/areas_service.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/presentation/compliance_level_labels.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/member_order_provider.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/features/areas/domain/area_summary.dart';

final areasServiceProvider = Provider<AreasService>(
  (ref) => const AreasService(),
);

/// Same calculation as Teams: the global period and the eligible payroll.
final areasPeriodSummaryProvider = FutureProvider<AreasPeriodSummary>((
  ref,
) async {
  if (!await ref.watch(hasTeamPeriodDataProvider.future)) {
    return const AreasPeriodSummary.noData();
  }
  final compliance = await ref.watch(teamComplianceProvider.future);
  final leaders = await ref.watch(leaderLabelsProvider.future);
  return ref
      .watch(areasServiceProvider)
      .buildPeriodSummary(compliance, resolveLeaders: leaders.forArea);
});

/// The Dashboard order: highest compliance first.
final areasByComplianceProvider = FutureProvider<List<AreaSummary>>((
  ref,
) async {
  final summary = await ref.watch(areasPeriodSummaryProvider.future);
  return ref.watch(areasServiceProvider).byCompliance(summary.areas);
});

List<FilterRow> areaFilterRows(AreaSummary area) => [
  for (final team in area.generalTeams.isEmpty ? [''] : area.generalTeams)
    FilterRow({'Área': area.name, 'Equipo': team, 'Estado': area.level.label}),
];

final areaFilterRowsProvider = FutureProvider<List<FilterRow>>((ref) async {
  final summary = await ref.watch(areasPeriodSummaryProvider.future);
  return summary.areas.expand(areaFilterRows).toList();
});

final filteredAreasProvider = FutureProvider<List<AreaSummary>>((ref) async {
  final selection = ref
      .watch(dataFilterSelectionProvider(DataFilterScope.areas))
      .values;
  final filters = ref.watch(dataFilterServiceProvider);
  final summary = await ref.watch(areasPeriodSummaryProvider.future);
  return summary.areas
      .where(
        (area) =>
            areaFilterRows(area).any((row) => filters.matches(selection, row)),
      )
      .toList();
});

/// Levels shown by the members table of the detail; empty = all. It is
/// discarded when leaving the screen.
final areaMemberStatusFilterProvider =
    NotifierProvider.autoDispose<
      AreaMemberStatusFilterNotifier,
      Set<ComplianceLevel>
    >(AreaMemberStatusFilterNotifier.new);

class AreaMemberStatusFilterNotifier extends Notifier<Set<ComplianceLevel>> {
  @override
  Set<ComplianceLevel> build() => const {};

  void select(Set<ComplianceLevel> levels) => state = Set.unmodifiable(levels);

  void clear() => state = const {};
}

/// The teams come from the same calculation as the Teams screen, so the cards
/// show the same numbers on both screens.
final areaDetailProvider = FutureProvider.family<AreaDetail?, String>((
  ref,
  areaName,
) async {
  final compliance = await ref.watch(teamComplianceProvider.future);
  final teamsSummary = await ref.watch(teamsPeriodSummaryProvider.future);
  final leaders = await ref.watch(leaderLabelsProvider.future);
  return ref
      .watch(areasServiceProvider)
      .getAreaDetail(
        compliance: compliance,
        teams: teamsSummary.teams,
        area: areaName,
        resolveLeaders: leaders.forArea,
      );
});

class AreaMembersView {
  final List<EmployeeCompliance> members;
  final Set<ComplianceLevel> levelOptions;
  final Set<ComplianceLevel> incompatibleLevels;

  const AreaMembersView({
    required this.members,
    required this.levelOptions,
    required this.incompatibleLevels,
  });
}

/// The area members filtered by level and sorted by the table's order.
final areaMembersViewProvider = FutureProvider.autoDispose
    .family<AreaMembersView, String>((ref, areaName) async {
      final detail = await ref.watch(areaDetailProvider(areaName).future);
      final selected = ref.watch(areaMemberStatusFilterProvider);
      final order = ref.watch(memberOrderProvider(MemberTable.area));
      final service = ref.watch(areasServiceProvider);
      final members = detail?.members ?? const <EmployeeCompliance>[];
      final present = service.levelsPresent(members);
      return AreaMembersView(
        members: ref
            .watch(memberOrderServiceProvider)
            .sort(service.membersAtLevels(members, selected), order),
        levelOptions: {...present, ...selected},
        incompatibleLevels: selected.difference(present),
      );
    });
