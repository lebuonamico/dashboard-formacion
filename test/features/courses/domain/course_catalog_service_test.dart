import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_catalog_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:flutter_test/flutter_test.dart';

Course _course(String id, String name) => Course(
  id: id,
  name: name,
  category: CourseCategory.softSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 4,
);

void main() {
  const service = CourseCatalogService();

  group('idsByName', () {
    test('La clave es el nombre normalizado', () {
      final ids = service.idsByName([_course(' C1 ', 'Oratoria Básica')]);

      expect(ids, {'oratoriabasica': 'C1'});
    });

    test('Dos filas del mismo curso con el mismo id no son ambiguas', () {
      final ids = service.idsByName([
        _course('C1', 'Oratoria'),
        _course('C1', ' ORATÓRIA '),
      ]);

      expect(ids['oratoria'], 'C1');
    });

    test('Un nombre con dos ids distintos queda vacío', () {
      final ids = service.idsByName([
        _course('C2', 'Excel'),
        _course('C3', 'excel'),
      ]);

      expect(ids['excel'], '');
    });

    test('Se ignoran los cursos sin id o sin nombre', () {
      final ids = service.idsByName([
        _course('  ', 'Oratoria'),
        _course('C4', ' -- '),
      ]);

      expect(ids, isEmpty);
    });
  });

  group('courseIdFor', () {
    final ids = {'oratoria': 'C1', 'excel': ''};

    test('Usa el id propio cuando lo hay', () {
      expect(service.courseIdFor(' C9 ', 'Oratoria', ids), 'C9');
    });

    test('Sin id, busca por el nombre normalizado', () {
      expect(service.courseIdFor(null, ' ORATORIA ', ids), 'C1');
      expect(service.courseIdFor('  ', 'Oratoria', ids), 'C1');
    });

    test('Un nombre ambiguo o desconocido no tiene id', () {
      expect(service.courseIdFor(null, 'Excel', ids), '');
      expect(service.courseIdFor(null, 'Python', ids), '');
    });
  });

  test('byName indexa por nombre normalizado y la última fila gana', () {
    final first = _course('C1', 'Oratoria');
    final last = _course('C2', 'ORATORIA');

    final byName = service.byName([first, last]);

    expect(byName.keys, ['oratoria']);
    expect(byName['oratoria'], same(last));
  });
}
