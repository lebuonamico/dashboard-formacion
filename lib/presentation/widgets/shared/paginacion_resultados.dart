import 'package:flutter/material.dart';

/// Leandro: Control visual de paginación compartido por los listados de la app.
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 20,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 20, color: const Color(0xFF0D53C3)),
              const SizedBox(width: 9),
              Text(
                'Mostrando $desde-$hasta de $totalResultados $etiquetaResultados',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Página anterior',
              ),
              const SizedBox(width: 12),
              Text(
                'Página ${paginaActual + 1} de $cantidadPaginas',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
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
