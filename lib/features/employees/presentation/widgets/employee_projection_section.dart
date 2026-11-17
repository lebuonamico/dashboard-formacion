import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/core/widgets/empty_data_state.dart';
import 'package:app_finnegans/features/projection/presentation/providers/projection_providers.dart';
import 'package:app_finnegans/features/projection/presentation/widgets/employee_projection_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Always shown, so an employee without data says so instead of losing the
/// section. Optional like the other projections: hidden while it loads or if
/// it fails.
class EmployeeProjectionSection extends ConsumerWidget {
  final String employeeId;
  final int year;
  final TextStyle titleStyle;

  const EmployeeProjectionSection({
    super.key,
    required this.employeeId,
    required this.year,
    required this.titleStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectionAsync = ref.watch(employeeProjectionProvider(employeeId));
    if (!projectionAsync.hasValue) return const SizedBox.shrink();
    final cutoffMonth = ref.watch(annualProjectionCutoffMonthProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Proyección a fin de año', style: titleStyle),
        const SizedBox(height: 12),
        if (projectionAsync.value case final projection?)
          EmployeeProjectionCard(projection: projection, year: year)
        else
          EmptyDataState(
            key: const Key('proyeccion_sin_datos'),
            compact: true,
            icon: Icons.trending_flat,
            title: 'Sin datos para proyectar.',
            message:
                'No hay datos cargados del colaborador'
                '${cutoffMonth == null ? ' en $year' : ' hasta ${monthName(cutoffMonth)} $year'}. '
                'La proyección usa sus meses con datos desde el ingreso.',
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
