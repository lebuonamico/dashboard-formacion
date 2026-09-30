import 'package:app_finnegans/data/moodle_cursos_api.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoodleCursosApi.parseCourses', () {
    test('mapea cursos Moodle y excluye el curso del sitio', () {
      final cursos = MoodleCursosApi.parseCourses([
        {'id': 1, 'fullname': 'Sitio'},
        {'id': 12, 'fullname': 'Seguridad informática'},
        {'id': 13, 'fullname': '   '},
      ]);

      expect(cursos, hasLength(1));
      expect(cursos.single.id, '12');
      expect(cursos.single.nombre, 'Seguridad informática');
      expect(cursos.single.tipo, TipoCurso.libresExploracion);
      expect(cursos.single.cargaHorariaHs, 0);
    });

    test('propaga errores devueltos por Moodle', () {
      expect(
        () => MoodleCursosApi.parseCourses({'message': 'Token inválido'}),
        throwsFormatException,
      );
    });
  });
}
