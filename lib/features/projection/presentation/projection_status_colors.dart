import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';
import 'package:flutter/widgets.dart';

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
