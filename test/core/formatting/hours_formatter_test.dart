import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('El desvío lleva signo y un decimal', () {
    expect(formatHoursDeviation(1.5), '+1.5 hs');
    expect(formatHoursDeviation(-2), '-2.0 hs');
  });

  test('Sin desvío cuenta como positivo', () {
    expect(formatHoursDeviation(0), '+0.0 hs');
  });

  test('La unidad se puede cambiar', () {
    expect(formatHoursDeviation(-0.25, unit: 'h'), '-0.3 h');
  });
}
