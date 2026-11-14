import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/reports/domain/report_output.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/providers/print_repository_provider.dart';
import 'package:app_finnegans/features/reports/presentation/providers/report_print_provider.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

const noReportData = 'No hay datos cargados para este período.';

/// Compact button that prints the screen's report, or downloads it on phones
/// ([reportOutputProvider]). Disabled while [report] loads; without data or on
/// error it explains why when tapped. On phones it is an icon, so it fits
/// next to the period's title.
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
    failure: (error) => error is FormatException
        ? error.message
        : 'No se pudo generar el reporte. Intentá nuevamente.',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(report);
    final generating = ref.watch(reportPrintProvider).isLoading;
    final download = ref.watch(reportOutputProvider) == ReportOutput.download;
    // When the period changes the previous value stays while reloading:
    // nothing is printed until the selected period's report is ready.
    final loading = reportAsync.isLoading;
    final help = switch (reportAsync) {
      AsyncValue(isLoading: true) => 'Cargando datos…',
      AsyncValue(hasError: true) => 'No se pudieron cargar los datos',
      AsyncValue(value: null) => noReportData,
      _ =>
        download
            ? 'Descarga un PDF con los datos de esta pantalla'
            : 'Genera un PDF con los datos de esta pantalla',
    };
    final label = generating
        ? 'Generando…'
        : download
        ? 'Descargar reporte'
        : 'Imprimir reporte';
    // Without data or on error it stays enabled to explain why there is no
    // report, instead of staying silent.
    final onPressed = generating || loading
        ? null
        : () => switch (reportAsync) {
            AsyncValue(:final error?) => showAppSnackBar(
              context,
              'No se pudieron cargar los datos. '
              '${loadErrorMessage(error)}',
            ),
            AsyncValue(value: final report?) => _print(context, ref, report),
            _ => showAppSnackBar(context, noReportData),
          };
    final windowSize = context.windowSize;
    final cs = context.colorScheme;
    final side = BorderSide(color: cs.outlineVariant);

    if (windowSize == WindowSize.compact) {
      return Tooltip(
        message: help,
        child: IconButton.outlined(
          key: const Key('print_report_icon'),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(48),
            foregroundColor: cs.primary,
            side: side,
          ),
          icon: generating
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: label,
                  ),
                )
              : Icon(
                  download ? Icons.download_outlined : Icons.print_outlined,
                  size: 20,
                  semanticLabel: label,
                ),
        ),
      );
    }

    // Below 840 px it is touched with a finger: 48 px high.
    final touch = windowSize.usesModalNavigation;
    return Tooltip(
      message: help,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          visualDensity: touch ? VisualDensity.standard : VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size(0, touch ? 48 : 30),
          foregroundColor: cs.primary,
          side: side,
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
            : Icon(
                download ? Icons.download_outlined : Icons.print_outlined,
                size: 16,
              ),
        label: Text(label),
      ),
    );
  }
}
