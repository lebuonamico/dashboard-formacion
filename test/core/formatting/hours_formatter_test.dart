import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Las horas enteras van sin decimales y el resto con uno', () {
    expect(formatHours(8), '8');
    expect(formatHours(0), '0');
    expect(formatHours(1.5), '1.5');
    expect(formatHours(2.26), '2.3');
  });

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
