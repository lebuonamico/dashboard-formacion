import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:app_finnegans/features/projection/domain/projection_service.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/area_compliance_providers.dart';
import 'package:flutter/widgets.dart';

/// Colores del semáforo de cumplimiento de un área: verde en objetivo, ámbar
/// en riesgo y rojo crítico.
extension ComplianceLevelColors on ComplianceLevel {
  ColorPair colors(BuildContext context) {
    final colors = context.colors;
    return switch (this) {
      ComplianceLevel.onTarget => colors.success,
      ComplianceLevel.atRisk => colors.warning,
      ComplianceLevel.critical => colors.danger,
    };
  }
}

/// Colores del estado de un equipo, con el mismo semáforo que las áreas.
extension TeamStatusColors on TeamStatus {
  ColorPair colors(BuildContext context) {
    final colors = context.colors;
    return switch (this) {
      TeamStatus.onTarget => colors.success,
      TeamStatus.atRisk => colors.warning,
      TeamStatus.critical => colors.danger,
    };
  }
}

/// Colores del semáforo de proyección anual, con el mismo verde, ámbar y rojo.
extension ProjectionStatusColors on ProjectionStatus {
  ColorPair colors(BuildContext context) {
    final colors = context.colors;
    return switch (this) {
      ProjectionStatus.onTrack => colors.success,
      ProjectionStatus.reachable => colors.warning,
      ProjectionStatus.atRisk => colors.danger,
    };
  }
}
