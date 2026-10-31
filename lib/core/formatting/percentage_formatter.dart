/// Compliance percentage without decimals, the same everywhere. It rounds,
/// but never shows 100 % if the target was not reached (99.6 → 99 %), so the
/// number does not contradict the traffic light.
String formatPercentage(double percentage) {
  var rounded = percentage.round();
  if (percentage < 100 && rounded >= 100) rounded = 99;
  return '$rounded%';
}
