import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/reports/presentation/providers/reports_providers.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

const noReportData = 'No hay datos cargados para este período.';

/// Botón compacto que imprime el reporte de la pantalla. Queda deshabilitado
/// mientras [report] carga; sin datos o con error avisa al tocarlo.
class PrintReportButton extends ConsumerStatefulWidget {
  final ProviderListenable<AsyncValue<TrainingReport?>> report;

  const PrintReportButton({super.key, required this.report});

  @override
  ConsumerState<PrintReportButton> createState() => _PrintReportButtonState();
}

class _PrintReportButtonState extends ConsumerState<PrintReportButton> {
  bool _generating = false;

  Future<void> _print(TrainingReport report) async {
    setState(() => _generating = true);
    try {
      await ref.read(printReportProvider)(report);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo generar el reporte: $error');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _notify(String message) => showAppSnackBar(context, message);

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(widget.report);
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
        onPressed: _generating || loading
            ? null
            : () => switch (reportAsync) {
                AsyncValue(:final error?) => _notify(
                  'No se pudieron cargar los datos. '
                  '${loadErrorMessage(error)}',
                ),
                AsyncValue(value: final report?) => _print(report),
                _ => _notify(noReportData),
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
        icon: _generating
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.print_outlined, size: 16),
        label: Text(_generating ? 'Generando…' : 'Imprimir reporte'),
      ),
    );
  }
}
