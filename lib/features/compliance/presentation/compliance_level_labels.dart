import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';

extension ComplianceLevelLabel on ComplianceLevel {
  String get label => switch (this) {
    ComplianceLevel.onTarget => 'En objetivo',
    ComplianceLevel.atRisk => 'En riesgo',
    ComplianceLevel.critical => 'Crítico',
  };

  String get pluralLabel => switch (this) {
    ComplianceLevel.onTarget => 'Cumplidos',
    ComplianceLevel.atRisk => 'En riesgo',
    ComplianceLevel.critical => 'Críticos',
  };
}
