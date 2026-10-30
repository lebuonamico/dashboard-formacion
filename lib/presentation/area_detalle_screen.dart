import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_detail_summary.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_members_table.dart';
import 'package:app_finnegans/presentation/widgets/shared/boton_imprimir_reporte.dart';
import 'package:app_finnegans/presentation/widgets/shared/periodo_filter_panel.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_team_card.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/comparacion_moodle_crm.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_kpi_section.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_card.dart';

class AreaDetailScreen extends ConsumerWidget {
  final String areaName;

  const AreaDetailScreen({super.key, required this.areaName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(areaDetailProvider(areaName));
    // Mantener la selección durante cargas o períodos sin integrantes.
    final membersFilter = ref.watch(areaMemberStatusFilterProvider);
    final hasDataAsync = ref.watch(hasTeamPeriodDataProvider);
    final scope = ref.watch(periodScopeProvider);
    final month = ref.watch(periodMonthFilterProvider);
    final year = ref.watch(periodYearFilterProvider);
    final periodControls = PeriodFilterPanel(
      included: 'todas las áreas',
      action: PrintReportButton(report: areaReportProvider(areaName)),
    );
    final requestedOrigin = GoRouterState.of(
      context,
    ).uri.queryParameters['origen'];
    const validOrigins = {'dashboard', 'areas', 'equipos'};
    final origin = validOrigins.contains(requestedOrigin)
        ? requestedOrigin!
        : 'areas';

    return Scaffold(
      backgroundColor: context.colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          AppTopBar(title: 'Detalle de área', onBack: () => context.pop()),
          Expanded(
            child: detailAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
              ),
              error: (error, _) => ErrorDataState(
                title: 'No pudimos cargar el área',
                error: error,
              ),
              data: (detail) => FadeIn(
                child: (() {
                  final period = periodLabel(scope, month, year);
                  final hasData = hasDataAsync.value ?? true;

                  return ListView(
                    padding: screenPadding,
                    children: [
                      periodControls,
                      const SizedBox(height: 22),
                      if (!hasData)
                        EmptyDataState.periodWithoutData(
                          icon: Icons.apartment_outlined,
                          period: period,
                        )
                      else if (detail == null)
                        EmptyDataState(
                          icon: Icons.apartment_outlined,
                          title:
                              'El área $areaName no tiene colaboradores elegibles en $period.',
                          message:
                              'Probá otro período o verificá la nómina del área.',
                        )
                      else
                        _AreaContent(
                          detail: detail,
                          filter: membersFilter,
                          period: detailedPeriodLabel(scope, month, year),
                          isAnnual: scope == PeriodScope.annual,
                          origin: origin,
                        ),
                    ],
                  );
                })(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaContent extends ConsumerWidget {
  final AreaDetailViewModel detail;
  final Set<String> filter;
  final String period;
  final bool isAnnual;
  final String origin;

  const _AreaContent({
    required this.detail,
    required this.filter,
    required this.period,
    required this.isAnnual,
    required this.origin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = detail.area;
    final year = ref.watch(periodYearFilterProvider);
    final month = ref.watch(periodMonthFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AreaDetailHeader(area: area, period: period),
        const SizedBox(height: 22),
        KpiCardRow(
          cards: [
            DashboardKpiCard(
              title: 'INTEGRANTES',
              value: '${area.memberCount}',
              suffix: 'nómina del área',
              progress: area.memberCount == 0
                  ? 0
                  : area.membersOnTarget / area.memberCount,
              progressLabel:
                  '${area.membersOnTarget} de ${area.memberCount} en objetivo',
              footer: '',
              icon: Icons.people_outline,
              color: context.colorScheme.primary,
              help: membersHelp('del área'),
            ),
            creditedHoursKpiCard(
              context,
              isAnnual: isAnnual,
              year: year,
              month: month,
              hours: area.completedHours,
              target: area.targetHours,
            ),
            DashboardKpiCard(
              title: 'OBJETIVO DEL PERÍODO',
              value: _hours(area.targetHours),
              suffix: 'según seniority',
              progress: 1,
              progressLabel: isAnnual
                  ? 'Suma de los objetivos del año'
                  : 'Objetivo del mes',
              footer: '',
              icon: Icons.flag_outlined,
              color: context.colors.violetAccent,
              help: targetHelp('el área'),
            ),
            complianceKpiCard(
              context,
              isAnnual: isAnnual,
              year: year,
              month: month,
              percentage: area.compliancePercentage,
              variation: ref
                  .watch(
                    complianceVariationProvider((area: area.name, team: null)),
                  )
                  .value,
              color: area.level.colors(context).text,
            ),
            if (ref
                    .watch(
                      annualProjectionProvider((area: area.name, team: null)),
                    )
                    .value
                case final projection?)
              projectionKpiCard(context, projection),
          ],
        ),
        const SizedBox(height: 16),
        AreaDetailSummary(area: area, isAnnual: isAnnual),
        if (detail.members.isNotEmpty) ...[
          const SizedBox(height: 16),
          MoodleCrmComparisonCards(complianceList: detail.members),
        ],
        const SizedBox(height: 24),
        AreaTeamsGrid(teams: detail.teams, isAnnual: isAnnual, origin: origin),
        const SizedBox(height: 24),
        AreaMembersTable(
          members: detail.members,
          filter: filter,
          onFilter: (value) =>
              ref.read(areaMemberStatusFilterProvider.notifier).state = value,
        ),
      ],
    );
  }

  String _hours(double value) => '${value.toStringAsFixed(1)} h';
}
