import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/team_status.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter/widgets.dart';

/// Colores del semáforo de cumplimiento de un área: verde en objetivo, ámbar
/// en riesgo y rojo crítico.
extension ColoresSemaforo on EstadoSemaforo {
  ParColores colores(BuildContext context) {
    final colores = context.colores;
    return switch (this) {
      EstadoSemaforo.verde => colores.exito,
      EstadoSemaforo.amarillo => colores.advertencia,
      EstadoSemaforo.rojo => colores.peligro,
    };
  }
}

/// Colores del estado de un equipo, con el mismo semáforo que las áreas.
extension ColoresEstadoEquipo on EstadoEquipo {
  ParColores colores(BuildContext context) {
    final colores = context.colores;
    return switch (this) {
      EstadoEquipo.enObjetivo => colores.exito,
      EstadoEquipo.enRiesgo => colores.advertencia,
      EstadoEquipo.critico => colores.peligro,
    };
  }
}

/// Colores del semáforo de proyección anual, con el mismo verde, ámbar y rojo.
extension ColoresEstadoProyeccion on EstadoProyeccion {
  ParColores colores(BuildContext context) {
    final colores = context.colores;
    return switch (this) {
      EstadoProyeccion.enCamino => colores.exito,
      EstadoProyeccion.alcanzable => colores.advertencia,
      EstadoProyeccion.enRiesgo => colores.peligro,
    };
  }
}
