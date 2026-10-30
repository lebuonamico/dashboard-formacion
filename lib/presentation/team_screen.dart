import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/boton_imprimir_reporte.dart';
import 'package:app_finnegans/presentation/widgets/shared/comparacion_moodle_crm.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/presentation/widgets/shared/periodo_filter_panel.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_detail_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_detail_summary.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_members_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String area;
  final String team;

  const TeamDetailScreen({super.key, required this.area, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(teamDetailProvider((area: area, team: team)));
    final hasDataAsync = ref.watch(hasTeamPeriodDataProvider);
    final scope = ref.watch(periodScopeProvider);
    final month = ref.watch(periodMonthFilterProvider);
    final year = ref.watch(periodYearFilterProvider);
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
          AppTopBar(title: 'Detalle de equipo', onBack: () => context.pop()),
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
