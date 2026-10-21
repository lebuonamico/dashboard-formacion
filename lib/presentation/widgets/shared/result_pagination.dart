import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// La pantalla calcula las páginas y este widget sólo muestra el estado y botones.
class PaginacionResultados extends StatelessWidget {
  final int paginaActual;
  final int cantidadPaginas;
  final int desde;
  final int hasta;
  final int totalResultados;
  final String etiquetaResultados;
  final IconData icono;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PaginacionResultados({
    super.key,
    required this.paginaActual,
    required this.cantidadPaginas,
    required this.desde,
    required this.hasta,
    required this.totalResultados,
    required this.etiquetaResultados,
    required this.icono,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final estiloTexto = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: context.panel().copyWith(color: cs.surfaceContainer),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 20,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 20, color: cs.primary),
              const SizedBox(width: 9),
              Text(
                'Mostrando $desde-$hasta de $totalResultados $etiquetaResultados',
                style: estiloTexto,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Leandro: llama a IconButton.filledTonal con onPrevious para solicitar la página anterior.
              IconButton.filledTonal(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Página anterior',
              ),
              const SizedBox(width: 12),
              Text(
                'Página ${paginaActual + 1} de $cantidadPaginas',
                style: estiloTexto.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              // Leandro: llama a IconButton.filledTonal con onNext para solicitar la página siguiente.
              IconButton.filledTonal(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Página siguiente',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
