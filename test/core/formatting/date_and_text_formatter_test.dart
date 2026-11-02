import 'package:app_finnegans/core/formatting/date_formatter.dart';
import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('La fecha va como dd/mm/aaaa con ceros a la izquierda', () {
    expect(formatDate(DateTime(2026, 7, 3)), '03/07/2026');
    expect(formatDate(DateTime(2026, 12, 31, 23, 59)), '31/12/2026');
  });

  test('Un texto vacío o en blanco se muestra como guion', () {
    expect(orDash(''), '-');
    expect(orDash('   '), '-');
    expect(orDash('Backend'), 'Backend');
  });
}
