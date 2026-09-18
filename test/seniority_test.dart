import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';

void main() {
  test('reconoce niveles de seniority con formatos de planilla', () {
    expect(Seniority.fromString('Junior 2do'), Seniority.junior2);
    expect(Seniority.fromString('Señor'), Seniority.senior1);
    expect(Seniority.fromString('Senior 3ro'), Seniority.senior3);
    expect(Seniority.fromString('SSR 2'), Seniority.semisenior2);
    expect(Seniority.fromString('J3'), Seniority.junior3);
    expect(Seniority.fromString('SS1'), Seniority.semisenior1);
    expect(Seniority.fromString('T'), Seniority.trainee);
    expect(Seniority.fromString('M'), Seniority.manager);
  });
}
