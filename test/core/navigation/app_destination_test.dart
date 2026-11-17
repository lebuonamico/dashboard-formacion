import 'package:app_finnegans/core/navigation/app_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Volver sin historial va a la sección de origen', () {
    expect(originBackPath('certificaciones', '/empleados'), '/certificaciones');
    expect(originBackPath('cursadas', '/empleados'), '/cursadas');
    expect(originBackPath('dashboard', '/areas'), '/dashboard');
  });

  test('Sin origen, o con uno desconocido, va al padre', () {
    expect(originBackPath(null, '/empleados'), '/empleados');
    expect(originBackPath('otra', '/areas'), '/areas');
  });
}
