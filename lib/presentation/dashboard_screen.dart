import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_areas_section.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_header.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_kpi_grid.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_category_hours.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_summary_charts.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_monthly_hours.dart';
import 'package:app_finnegans/presentation/widgets/dashboard/dashboard_area_compliance_panel.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cumplimientoAsync = ref.watch(cumplimientoGlobalProvider);
    final areasAsync = ref.watch(semaforoPorAreaProvider);
    final cargasAsync = ref.watch(cargasDeHorasCRMProvider);
    final equiposAsync = ref.watch(equiposGlobalProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                const DashboardHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DashboardKpiGrid(
                          cumplimientosAsync: cumplimientoAsync,
                          cargasAsync: cargasAsync,
                          areasAsync: areasAsync,
                          equiposAsync: equiposAsync,
                        ),
                        const SizedBox(height: 28),
                        DashboardCategoryHours(
                          cumplimientosAsync: cumplimientoAsync,
                        ),
                        const SizedBox(height: 28),
                        DashboardSummaryCharts(
                          cumplimientosAsync: cumplimientoAsync,
                        ),
                        const SizedBox(height: 28),
                        DashboardAreaCompliancePanel(areasAsync: areasAsync),
                        const SizedBox(height: 28),
                        DashboardMonthlyHours(cargasAsync: cargasAsync),
                        const SizedBox(height: 28),
                        DashboardAreasSection(areasAsync: areasAsync),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
