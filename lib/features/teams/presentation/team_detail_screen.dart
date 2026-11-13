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
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String area;
  final String team;

  const TeamDetailScreen({super.key, required this.area, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = (area: area, team: team);
    final period = ref.watch(periodFilterProvider);
    final periodControls = PeriodFilterPanel(
      included: 'los integrantes del equipo elegibles',
      action: PrintReportButton(report: teamReportProvider(section)),
    );

    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          AppTopBar(
            title: 'Detalle de equipo',
            // Opened from an area (or from the home screen through one), it
            // goes back to that area.
            backTo: switch (GoRouterState.of(
              context,
            ).uri.queryParameters['origen']) {
              'areas' || 'dashboard' => '/areas/${Uri.encodeComponent(area)}',
              _ => '/equipos',
            },
          ),
          Expanded(
            child: ref
                .watch(hasTeamPeriodDataProvider)
                .when(
                  skipLoadingOnReload: true,
                  loading: () => const _Loading(),
                  error: (error, _) => ErrorDataState(
                    title: 'No pudimos cargar el equipo',
                    error: error,
                    onRetry: () => ref.invalidate(hasTeamPeriodDataProvider),
                  ),
                  data: (hasData) => hasData
                      ? _TeamDetailBody(
                          section: section,
                          periodControls: periodControls,
                        )
                      : FadeIn(
                          child: _EmptyContent(
                            periodControls: periodControls,
                            child: EmptyDataState.periodWithoutData(
                              icon: Icons.groups_outlined,
                              period: periodLabel(
                                period.scope,
                                period.month,
                                period.year,
                              ),
                            ),
                          ),
                        ),
                ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(color: context.colorScheme.primary),
  );
}

class _TeamDetailBody extends ConsumerWidget {
  final ({String area, String team}) section;
  final Widget periodControls;

  const _TeamDetailBody({required this.section, required this.periodControls});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodFilterProvider);

    return ref
        .watch(teamDetailProvider(section))
        .when(
          skipLoadingOnReload: true,
          loading: () => const _Loading(),
          error: (error, _) => ErrorDataState(
            title: 'No pudimos cargar el equipo',
            error: error,
            onRetry: () => ref.invalidate(teamDetailProvider(section)),
          ),
          data: (detail) => FadeIn(
            child: detail == null
                ? _EmptyContent(
                    periodControls: periodControls,
                    child: EmptyDataState(
                      icon: Icons.groups_outlined,
                      title:
                          'El equipo ${section.team} no tiene colaboradores elegibles en ${periodLabel(period.scope, period.month, period.year)}.',
                      message:
                          'Probá otro período o verificá los colaboradores del equipo.',
                    ),
                  )
                : _TeamDetailContent(
                    detail: detail,
                    section: section,
                    periodLabel: detailedPeriodLabel(
                      period.scope,
                      period.month,
                      period.year,
                    ),
                    isAnnual: period.scope == PeriodScope.annual,
                    periodControls: periodControls,
                  ),
          ),
        );
  }
}

class _TeamDetailContent extends StatelessWidget {
  final TeamDetail detail;
  final ({String area, String team}) section;
  final String periodLabel;
  final bool isAnnual;
  final Widget periodControls;

  const _TeamDetailContent({
    required this.detail,
    required this.section,
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
        TeamMembersTable(section: section),
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
