import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:app_finnegans/features/reports/presentation/widgets/print_report_button.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/moodle_crm_comparison_cards.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:app_finnegans/core/widgets/fade_in.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/period_filter_panel.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_detail_kpi_section.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_detail_summary.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_members_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String area;
  final String team;

  const TeamDetailScreen({super.key, required this.area, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailProvider((area: area, team: team)));
    final hasDataAsync = ref.watch(hasTeamPeriodDataProvider);
    final scope = ref.watch(periodFilterProvider).scope;
    final month = ref.watch(periodFilterProvider).month;
    final year = ref.watch(periodFilterProvider).year;
    final detailedLabel = detailedPeriodLabel(scope, month, year);

    final periodControls = PeriodFilterPanel(
      action: PrintReportButton(
        report: teamReportProvider((area: area, team: team)),
      ),
    );

    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          const AppTopBar(title: 'Detalle de equipo', backTo: '/equipos'),
          Expanded(
            child: detailAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar el equipo',
                error: error,
                onRetry: () => ref.invalidate(
                  teamDetailProvider((area: area, team: team)),
                ),
              ),
              data: (detail) {
                final label = periodLabel(scope, month, year);
                final Widget content;
                if (!(hasDataAsync.value ?? true)) {
                  content = _EmptyContent(
                    periodControls: periodControls,
                    child: EmptyDataState.periodWithoutData(
                      icon: Icons.groups_outlined,
                      period: label,
                    ),
                  );
                } else if (detail == null) {
                  content = _EmptyContent(
                    periodControls: periodControls,
                    child: EmptyDataState(
                      icon: Icons.groups_outlined,
                      title:
                          'El equipo $team no tiene colaboradores elegibles en $label.',
                      message:
                          'Probá otro período o verificá la nómina del equipo.',
                    ),
                  );
                } else {
                  content = _TeamDetailContent(
                    detail: detail,
                    periodLabel: detailedLabel,
                    isAnnual: scope == PeriodScope.annual,
                    periodControls: periodControls,
                  );
                }
                return FadeIn(child: content);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamDetailContent extends StatelessWidget {
  final TeamDetail detail;
  final String periodLabel;
  final bool isAnnual;
  final Widget periodControls;

  const _TeamDetailContent({
    required this.detail,
    required this.periodLabel,
    required this.isAnnual,
    required this.periodControls,
  });

  @override
  Widget build(BuildContext context) {
    final team = detail.overview;

    return ListView(
      padding: screenPadding,
      children: [
        periodControls,
        const SizedBox(height: 22),
        TeamDetailHeader(team: team, periodLabel: periodLabel),
        const SizedBox(height: 22),
        TeamDetailKpiSection(team: team, isAnnual: isAnnual),
        const SizedBox(height: 16),
        TeamDetailSummary(team: team, isAnnual: isAnnual),
        if (detail.members.isNotEmpty) ...[
          const SizedBox(height: 16),
          MoodleCrmComparisonCards(complianceList: detail.members),
        ],
        const SizedBox(height: 24),
        TeamMembersTable(members: detail.members),
      ],
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final Widget periodControls;
  final Widget child;

  const _EmptyContent({required this.periodControls, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: screenPadding,
      children: [periodControls, const SizedBox(height: 22), child],
    );
  }
}
