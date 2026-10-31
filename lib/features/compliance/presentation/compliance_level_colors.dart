import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:flutter/widgets.dart';

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
