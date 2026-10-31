enum ComplianceLevel { onTarget, atRisk, critical }

/// The 100/70 cuts of the traffic light, in a single place.
class ComplianceLevelService {
  static const onTargetPercentage = 100.0;
  static const atRiskPercentage = 70.0;

  const ComplianceLevelService();

  ComplianceLevel fromPercentage(double percentage) {
    if (percentage >= onTargetPercentage) return ComplianceLevel.onTarget;
    if (percentage >= atRiskPercentage) return ComplianceLevel.atRisk;
    return ComplianceLevel.critical;
  }
}
