import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Las horas se redondean a enteros', () {
    expect(formatHours(8), '8');
    expect(formatHours(0), '0');
    expect(formatHours(1.5), '2');
    expect(formatHours(2.26), '2');
    expect(formatHours(-0.4), '0');
  });

  test('Las horas con decimales van enteras o con uno, con coma', () {
    expect(formatHoursPrecise(8), '8');
    expect(formatHoursPrecise(1.5), '1,5');
    expect(formatHoursPrecise(2.26), '2,3');
    // Redondea a la décima antes de decidir: no muestra "5,0".
    expect(formatHoursPrecise(4.96), '5');
    // toStringAsFixed solo daría 4.3.
    expect(formatHoursPrecise(4.35), '4,4');
  });

  test('Los decimales llevan coma', () {
    expect(formatDecimal(2.5), '2,5');
    expect(formatDecimal(2.5, digits: 2), '2,50');
    expect(formatDecimal(-0.2), '-0,2');
  });

  test('Lo logrado debajo del objetivo no redondea hasta el objetivo', () {
    expect(formatAchievedHours(7.6, target: 8), '7');
    expect(formatAchievedHours(8, target: 8), '8');
    expect(formatAchievedHours(9.4, target: 8), '9');
    expect(formatAchievedHours(3.4, target: 8), '3');
    expect(formatAchievedHours(0.2, target: 0), '0');
  });

  test('Lo que falta redondea hacia arriba', () {
    expect(formatMissingHours(0.3), '1');
    expect(formatMissingHours(3), '3');
    expect(formatMissingHours(15.2), '16');
    expect(formatMissingHours(0), '0');
    expect(formatMissingHours(-2), '0');
  });

  test('El desvío lleva signo y es entero', () {
    expect(formatHoursDeviation(1.5), '+2 hs');
    expect(formatHoursDeviation(-2), '-2 hs');
  });

  test('Un desvío que redondea a 0 va sin signo', () {
    expect(formatHoursDeviation(0), '0 hs');
    expect(formatHoursDeviation(-0.3), '0 hs');
    expect(formatHoursDeviation(0.4), '0 hs');
  });
}
