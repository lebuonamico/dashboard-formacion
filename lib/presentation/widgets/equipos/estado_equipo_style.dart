import 'package:app_finnegans/domain/modelos/estado_equipo.dart';
import 'package:flutter/material.dart';

/// Leandro: Convierte el estado calculado por el servicio en colores de la interfaz.
extension EstadoEquipoStyle on EstadoEquipo {
  Color get colorTexto {
    switch (this) {
      case EstadoEquipo.enObjetivo:
        return const Color(0xFF16A34A);
      case EstadoEquipo.enRiesgo:
        return const Color(0xFFD97706);
      case EstadoEquipo.critico:
        return const Color(0xFFDC2626);
    }
  }

  Color get colorFondo {
    switch (this) {
      case EstadoEquipo.enObjetivo:
        return const Color(0xFFDCFCE7);
      case EstadoEquipo.enRiesgo:
        return const Color(0xFFFEF3C7);
      case EstadoEquipo.critico:
        return const Color(0xFFFEE2E2);
    }
  }
}
