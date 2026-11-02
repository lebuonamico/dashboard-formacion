import 'package:app_finnegans/features/courses/data/in_memory_courses_repository.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/imports/domain/snapshot_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

Employee _employee(String employeeId, {bool isActive = true}) => Employee(
  employeeId: employeeId,
  firstName: 'Persona',
  lastName: employeeId,
  seniority: Seniority.junior1,
  area: 'Producto',
  email: 'persona$employeeId@finnegans.com',
  hireDate: DateTime(2024),
  isActive: isActive,
);

Course _course(String id, String name) => Course(
  id: id,
  name: name,
  category: CourseCategory.softSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 2,
);

void main() {
  const service = SnapshotSyncService();

  group('Nómina', () {
    test(
      'da de baja a los ausentes, reactiva y cuenta sobre el archivo',
      () async {
        final repository = InMemoryEmployeesRepository(
          employees: [
            _employee('1'),
            _employee('2'),
            _employee('3', isActive: false),
          ],
        );

        final result = await service.syncPayroll(repository, [
          _employee('1'),
          _employee('3'),
          _employee('4'),
        ]);

        final byId = {
          for (final employee in await repository.getEmployees())
            employee.employeeId: employee.isActive,
        };
        expect(byId, {'1': true, '2': false, '3': true, '4': true});
        expect(result.processedRecords, 3);
        expect(result.inserted, 1);
        // 1 y 3 se reescriben y 2 se da de baja.
        expect(result.updated, 3);
      },
    );

    test('un ausente que ya estaba de baja no se vuelve a escribir', () async {
      final repository = InMemoryEmployeesRepository(
        employees: [_employee('1'), _employee('2', isActive: false)],
      );

      final result = await service.syncPayroll(repository, [_employee('1')]);

      expect(result.updated, 1);
    });

    test('rechaza una foto vacía o con legajos en blanco', () async {
      final repository = InMemoryEmployeesRepository(employees: []);

      for (final snapshot in [
        <Employee>[],
        [_employee(' ')],
      ]) {
        await expectLater(
          service.syncPayroll(repository, snapshot),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'La foto de Nómina está vacía o tiene claves inválidas.',
            ),
          ),
        );
      }
      expect(await repository.getEmployees(), isEmpty);
    });
  });

  group('Catálogo de cursos', () {
    test('conserva el ID del curso con el mismo nombre', () async {
      final repository = InMemoryCoursesRepository([
        _course('107', 'ISO 9001'),
        _course('200', 'Curso discontinuado'),
      ]);

      final result = await service.syncCourseCatalog(repository, [
        _course('30014', ' iso 9001 '),
        _course('30001', 'Administración de accesos'),
      ]);

      final byId = {
        for (final course in await repository.getCourses())
          course.id: course.isActive,
      };
      expect(byId, {'107': true, '200': false, '30001': true});
      expect(result.processedRecords, 2);
      expect(result.inserted, 1);
      expect(result.updated, 2);
    });

    test('rechaza una foto vacía o con IDs en blanco', () async {
      final repository = InMemoryCoursesRepository([]);

      await expectLater(
        service.syncCourseCatalog(repository, [_course('', 'Sin ID')]),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'La foto de Cursos está vacía o tiene claves inválidas.',
          ),
        ),
      );
    });
  });
}
