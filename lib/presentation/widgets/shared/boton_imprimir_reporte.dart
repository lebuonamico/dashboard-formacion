import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/reportes/reporte_pdf.dart';
import 'package:flutter/material.dart';

/// Botón compacto que arma el reporte de la pantalla y abre el diálogo de
/// impresión. [construirReporte] devuelve `null` mientras faltan datos.
class BotonImprimirReporte extends StatefulWidget {
  final ReporteFormacion? Function() construirReporte;

  const BotonImprimirReporte({super.key, required this.construirReporte});

  @override
  State<BotonImprimirReporte> createState() => _BotonImprimirReporteState();
}

class _BotonImprimirReporteState extends State<BotonImprimirReporte> {
  bool _generando = false;

  Future<void> _imprimir() async {
    final messenger = ScaffoldMessenger.of(context);
    final reporte = widget.construirReporte();
    if (reporte == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Esperá a que terminen de cargar los datos.'),
        ),
      );
      return;
    }
    setState(() => _generando = true);
    try {
      await imprimirReporte(reporte);
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
    final cs = context.colorScheme;
    return Tooltip(
      message: 'Genera un PDF con los datos de esta pantalla',
      child: OutlinedButton.icon(
        onPressed: _generando ? null : _imprimir,
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
