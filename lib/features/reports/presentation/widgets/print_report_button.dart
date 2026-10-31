import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/providers/report_print_provider.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

const noReportData = 'No hay datos cargados para este período.';

/// Botón compacto que imprime el reporte de la pantalla. Queda deshabilitado
/// mientras [report] carga; sin datos o con error avisa al tocarlo.
class PrintReportButton extends ConsumerWidget {
  final ProviderListenable<AsyncValue<TrainingReport?>> report;

  const PrintReportButton({super.key, required this.report});

  Future<void> _print(
    BuildContext context,
    WidgetRef ref,
    TrainingReport report,
  ) => runWithFeedback(
    context,
    action: () => ref.read(reportPrintProvider.notifier).printReport(report),
    failure: (error) => 'No se pudo generar el reporte: $error',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(report);
    final generating = ref.watch(reportPrintProvider).isLoading;
    // Al cambiar el período queda el valor anterior mientras recarga: no se
    // imprime hasta tener el del período elegido.
    final loading = reportAsync.isLoading;
    final help = switch (reportAsync) {
      AsyncValue(isLoading: true) => 'Cargando datos…',
      AsyncValue(hasError: true) => 'No se pudieron cargar los datos',
      AsyncValue(value: null) => noReportData,
      _ => 'Genera un PDF con los datos de esta pantalla',
    };
    final cs = context.colorScheme;

    return Tooltip(
      message: help,
      child: OutlinedButton.icon(
        // Sin datos o con error sigue habilitado para explicar por qué no
        // hay reporte, en vez de quedar mudo.
        onPressed: generating || loading
            ? null
            : () => switch (reportAsync) {
                AsyncValue(:final error?) => showAppSnackBar(
                  context,
                  'No se pudieron cargar los datos. '
                  '${loadErrorMessage(error)}',
                ),
                AsyncValue(value: final report?) => _print(
                  context,
                  ref,
                  report,
                ),
                _ => showAppSnackBar(context, noReportData),
              },
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 30),
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.outlineVariant),
          textStyle: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: generating
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.print_outlined, size: 16),
        label: Text(generating ? 'Generando…' : 'Imprimir reporte'),
      ),
    );
  }
}
