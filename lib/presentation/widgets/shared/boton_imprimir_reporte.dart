import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Botón compacto que imprime el reporte de la pantalla. Queda deshabilitado
/// mientras [reporte] carga o si el período no tiene nada para reportar.
class BotonImprimirReporte extends ConsumerStatefulWidget {
  final ProviderListenable<AsyncValue<ReporteFormacion?>> reporte;

  const BotonImprimirReporte({super.key, required this.reporte});

  @override
  ConsumerState<BotonImprimirReporte> createState() =>
      _BotonImprimirReporteState();
}

class _BotonImprimirReporteState extends ConsumerState<BotonImprimirReporte> {
  bool _generando = false;

  Future<void> _imprimir(ReporteFormacion reporte) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generando = true);
    try {
      await ref.read(imprimirReporteProvider)(reporte);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo generar el reporte: $error')),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reporteAsync = ref.watch(widget.reporte);
    // Al cambiar el período queda el valor anterior mientras recarga: no se
    // imprime hasta tener el del período elegido.
    final reporte = reporteAsync.isLoading ? null : reporteAsync.value;
    final ayuda = switch (reporteAsync) {
      AsyncValue(isLoading: true) => 'Cargando datos…',
      AsyncValue(hasError: true) => 'No se pudieron cargar los datos',
      AsyncValue(value: null) => 'No hay datos para reportar en este período',
      _ => 'Genera un PDF con los datos de esta pantalla',
    };
    final cs = context.colorScheme;

    return Tooltip(
      message: ayuda,
      child: OutlinedButton.icon(
        onPressed: _generando || reporte == null
            ? null
            : () => _imprimir(reporte),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 30),
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.outlineVariant),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        icon: _generando
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.print_outlined, size: 16),
        label: Text(_generando ? 'Generando…' : 'Imprimir reporte'),
      ),
    );
  }
}
