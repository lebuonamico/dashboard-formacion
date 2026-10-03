import 'package:flutter/material.dart';

// Leandro: Paleta compartida por todos los widgets de Equipos.
const equiposInk = Color(0xFF0F172A);
const equiposMuted = Color(0xFF64748B);
const equiposBorder = Color(0xFFE2E8F0);
const equiposBackground = Color(0xFFF8FAFC);
const equiposBrand = Color(0xFF0D53C3);

// Leandro: Decoración común de los paneles para mantener un diseño consistente.
BoxDecoration equiposPanelDecoration({bool withShadow = false}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: equiposBorder),
    boxShadow: withShadow
        ? const [
            BoxShadow(
              color: Color(0x090F172A),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ]
        : null,
  );
}
