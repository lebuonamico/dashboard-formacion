import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

class ComplianceService {
  /// Versiones del plan de formación. Sin versiones rige el plan por defecto.
  final TrainingPlanHistory plans;

  const ComplianceService({this.plans = const TrainingPlanHistory.empty()});

  /// [year] y [month] eligen la versión del plan que fija el objetivo. Sin
  /// período se usa la vigente hoy.
  List<EmployeeCompliance> calculateComplianceGlobal({
    required List<Employee> employees,
    required List<Course> courses,
    required List<CrmTimeEntry> timeEntries,
    required List<LmsCertification> lmsCertifications,
    int? year,
    int? month,
  }) {
    assert((year == null) == (month == null), 'anio y mes van juntos');
    final plan = year != null && month != null
        ? plans.currentIn(year, month)
        : plans.current;
    final coursesMap = {
      for (final course in courses) normalizeCourseName(course.name): course,
    };
    final timeEntriesByEmployeeId = <String, List<CrmTimeEntry>>{};
    for (final timeEntry in timeEntries) {
      timeEntriesByEmployeeId
          .putIfAbsent(timeEntry.employeeId, () => [])
          .add(timeEntry);
    }
    final certificationsByEmployeeId = <String, List<LmsCertification>>{};
    for (final certification in lmsCertifications) {
      certificationsByEmployeeId
          .putIfAbsent(certification.employeeId, () => [])
          .add(certification);
    }

    return employees.map((employee) {
      // Leandro: llama a _horasPorCategoriaEnCero para inicializar las horas del colaborador sin inventar actividad.
      final creditedHours = _zeroHoursByCategory();
      final declaredHours = _zeroHoursByCategory();

      final employeeTimeEntries =
          timeEntriesByEmployeeId[employee.employeeId] ??
          const <CrmTimeEntry>[];
      for (final timeEntry in employeeTimeEntries) {
        // Libres y Dictado no pasan por el LMS: la Clasificación CRM las acredita.
        final categoryOnlyCrm = timeEntry.categoryOnlyCrm;
        if (categoryOnlyCrm != null) {
          declaredHours[categoryOnlyCrm] =
              (declaredHours[categoryOnlyCrm] ?? 0) + timeEntry.hours;
          creditedHours[categoryOnlyCrm] =
              (creditedHours[categoryOnlyCrm] ?? 0) + timeEntry.hours;
          continue;
        }

        // Leandro: llama a normalizarNombreCurso para buscar el curso CRM en el catálogo con un nombre uniforme.
        final normalizedCourse = normalizeCourseName(timeEntry.courseName);
        final course = coursesMap[normalizedCourse];
        if (course != null) {
          declaredHours[course.category] =
              (declaredHours[course.category] ?? 0) + timeEntry.hours;
        }
      }

      // Negocio y Blandas: cada curso finalizado en el LMS acredita su carga horaria.
      final validatedCourses = <String>{};
      final employeeCertifications =
          certificationsByEmployeeId[employee.employeeId] ??
          const <LmsCertification>[];
      for (final certification in employeeCertifications) {
        // Leandro: llama a normalizarNombreCurso para buscar el curso finalizado en el catálogo.
        final normalizedCourse = normalizeCourseName(certification.courseName);
        if (!certification.isCompleted ||
            !validatedCourses.add(normalizedCourse)) {
          continue;
        }

        final course = coursesMap[normalizedCourse];
        // Libres y Dictado se acreditan solo por CRM.
        if (course == null ||
            course.category == CourseCategory.exploration ||
            course.category == CourseCategory.teaching) {
          continue;
        }

        final hoursToCredit = course.workloadHours < 0
            ? 0.0
            : course.workloadHours;
        creditedHours[course.category] =
            (creditedHours[course.category] ?? 0) + hoursToCredit;
      }

      // Requerimientos mensuales según el seniority del empleado.
      final requiredHours = Map.of(plan.requiredHours(employee.seniority));

      // Leandro: llama a CumplimientoEmpleado para entregar las horas validadas, declaradas y requeridas de cada persona.
      return EmployeeCompliance(
        employee: employee,
        creditedHours: creditedHours,
        declaredHours: declaredHours,
        requiredHours: requiredHours,
      );
    }).toList();
  }

  static Map<CourseCategory, double> _zeroHoursByCategory() => {
    for (final type in CourseCategory.values) type: 0.0,
  };

  /// Se llama por cada carga y certificación, con pocos nombres distintos:
  /// cada uno se normaliza una sola vez.
  static String normalizeCourseName(String name) =>
      _normalizedNames[name] ??= _normalizeName(name);

  static final _normalizedNames = <String, String>{};

  static String _normalizeName(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
