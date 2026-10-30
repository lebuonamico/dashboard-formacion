import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/cursada.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/repositorios/formacion_repository.dart';

class MockTrainingRepository implements TrainingRepository {
  @override
  Future<List<Employee>> getEmployees() async {
    // Simula delay de red o lectura de BD
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Employee(
        employeeId: 'EMP-001',
        firstName: 'Sofía',
        lastName: 'Martínez',
        seniority: Seniority.trainee,
        area: 'Desarrollo',
        team: 'Core ERP Backend',
        manager: 'Lucas Gómez',
        email: 'sofia.martinez@empresa.com',
      ),
      Employee(
        employeeId: 'EMP-002',
        firstName: 'Lucas',
        lastName: 'Gómez',
        seniority: Seniority.junior3,
        area: 'Desarrollo',
        team: 'Core ERP Backend',
        manager: 'Lucas Gómez',
        email: 'lucas.gomez@empresa.com',
      ),
      Employee(
        employeeId: 'EMP-003',
        firstName: 'Valeria',
        lastName: 'Ríos',
        seniority: Seniority.semisenior2,
        area: 'Arquitectura',
        team: 'Frontend Arquitectura & UI',
        manager: 'Valeria Ríos',
        email: 'valeria.rios@empresa.com',
      ),
      Employee(
        employeeId: 'EMP-004',
        firstName: 'Martín',
        lastName: 'Castro',
        seniority: Seniority.senior2,
        area: 'Desarrollo',
        team: 'Core ERP Backend',
        manager: 'Lucas Gómez',
        email: 'martin.castro@empresa.com',
      ),
      Employee(
        employeeId: 'EMP-005',
        firstName: 'Carolina',
        lastName: 'Herrera',
        seniority: Seniority.manager,
        area: 'Management',
        team: 'Formación y Liderazgo',
        manager: 'Carolina Herrera',
        email: 'carolina.herrera@empresa.com',
      ),
      Employee(
        employeeId: 'EMP-006',
        firstName: 'Diego',
        lastName: 'Fernández',
        seniority: Seniority.senior1,
        area: 'Infraestructura',
        team: 'Cloud Infrastructure',
        manager: 'Diego Fernández',
        email: 'diego.fernandez@empresa.com',
      ),
      Employee(
        employeeId: 'EMP-007',
        firstName: 'Sebastian',
        lastName: 'Gonzalez',
        seniority: Seniority.senior2,
        area: 'Calidad',
        team: 'QA Automation',
        manager: 'Sebastian Gonzalez',
        email: 'sebastian.gonzalez@empresa.com',
      ),

      // Agrega más empleados según sea necesario
    ];
  }

  @override
  Future<List<Course>> getCourses() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Course(
        id: 'CUR-01',
        name: 'Estrategia y Modelos de Negocio',
        category: CourseCategory.businessSkills,
        courseArea: 'Negocio',
        instructorEmployeeId: 'EMP-004', // Martín Castro
        workloadHours: 4.0,
      ),
      Course(
        id: 'CUR-02',
        name: 'Finanzas Básicas para Tech',
        category: CourseCategory.businessSkills,
        courseArea: 'Finanzas',
        instructorEmployeeId: 'EMP-005', // Carolina Herrera
        workloadHours: 2.0,
      ),
      Course(
        id: 'CUR-03',
        name: 'Comunicación Asertiva y Feedback',
        category: CourseCategory.softSkills,
        courseArea: 'RRHH',
        instructorEmployeeId: 'EMP-004', // Martín Castro
        workloadHours: 4.0,
      ),
      Course(
        id: 'CUR-04',
        name: 'Gestión del Tiempo y Priorización',
        category: CourseCategory.softSkills,
        courseArea: 'Productividad',
        instructorEmployeeId: 'EMP-003', // Valeria Ríos
        workloadHours: 2.0,
      ),
      Course(
        id: 'CUR-05',
        name: 'Exploración de Arquitecturas Serverless',
        category: CourseCategory.exploration,
        courseArea: 'Innovación',
        instructorEmployeeId: 'EMP-003', // Valeria Ríos
        workloadHours: 1.0,
      ),
      Course(
        id: 'CUR-06',
        name: 'Machine Learning aplicado a Negocios',
        category: CourseCategory.exploration,
        courseArea: 'Data',
        instructorEmployeeId: 'EMP-004', // Martín Castro
        workloadHours: 8.0,
      ),
    ];
  }

  @override
  Future<List<LegacyTimeEntry>> getLegacyTimeEntries() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      // EMP-001 (Trainee): Necesita 4h Negocio + 4h Blandas (Cumple 100%)
      LegacyTimeEntry(
        id: 'CSD-01',
        courseId: 'CUR-01',
        employeeId: 'EMP-001',
        date: DateTime(2026, 7, 10),
      ),
      LegacyTimeEntry(
        id: 'CSD-02',
        courseId: 'CUR-03',
        employeeId: 'EMP-001',
        date: DateTime(2026, 7, 18),
      ),

      // EMP-002 (Junior 3): Necesita 3h Negocio + 4h Blandas + 1h Libres (Tiene 2h Negocio + 4h Blandas)
      LegacyTimeEntry(
        id: 'CSD-03',
        courseId: 'CUR-02',
        employeeId: 'EMP-002',
        date: DateTime(2026, 7, 12),
      ),
      LegacyTimeEntry(
        id: 'CSD-04',
        courseId: 'CUR-03',
        employeeId: 'EMP-002',
        date: DateTime(2026, 7, 25),
      ),

      // EMP-003 (Semisenior 2): Necesita 2h Negocio + 4h Blandas + 1h Libres + 1h Dictado
      // Dicta CUR-04 (2h) y CUR-05 (1h) -> 3h Dictadas
      LegacyTimeEntry(
        id: 'CSD-05',
        courseId: 'CUR-02',
        employeeId: 'EMP-003',
        date: DateTime(2026, 8, 5),
      ),
      LegacyTimeEntry(
        id: 'CSD-06',
        courseId: 'CUR-03',
        employeeId: 'EMP-003',
        date: DateTime(2026, 8, 12),
      ),
      LegacyTimeEntry(
        id: 'CSD-07',
        courseId: 'CUR-05',
        employeeId: 'EMP-003',
        date: DateTime(2026, 8, 20),
      ),

      // EMP-004 (Senior 2): Necesita 2h Blandas + 2h Libres + 4h Dictado
      // Dicta CUR-01 (4h), CUR-03 (4h), CUR-06 (8h) -> 16h Dictadas
      LegacyTimeEntry(
        id: 'CSD-08',
        courseId: 'CUR-04',
        employeeId: 'EMP-004',
        date: DateTime(2026, 8, 15),
      ),
      LegacyTimeEntry(
        id: 'CSD-09',
        courseId: 'CUR-05',
        employeeId: 'EMP-004',
        date: DateTime(2026, 8, 22),
      ),

      // EMP-005 (Manager): Necesita 8h Libres (Cumple 100%)
      LegacyTimeEntry(
        id: 'CSD-10',
        courseId: 'CUR-06',
        employeeId: 'EMP-005',
        date: DateTime(2026, 8, 28),
      ),
    ];
  }

  @override
  Future<void> replaceData({
    required List<Employee> employees,
    required List<Course> courses,
    required List<LegacyTimeEntry> timeEntries,
  }) async {}

  @override
  Future<void> resetToMock() async {}
}
