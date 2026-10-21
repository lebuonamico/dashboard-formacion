import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Etiqueta rectangular chica con texto y fondo de un [ParColores]: la base
/// de los chips de seniority, tipo de curso y estados.
class EtiquetaColor extends StatelessWidget {
  final String texto;
  final ParColores colores;
  final IconData? icono;

  const EtiquetaColor({
    super.key,
    required this.texto,
    required this.colores,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colores.fondo,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: colores.texto),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colores.texto,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
