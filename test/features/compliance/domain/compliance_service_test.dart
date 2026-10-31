import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/teams/domain/teams_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';

void main() {
  final employee = Employee(
    hireDate: DateTime(2024, 1, 1),
    employeeId: '100',
    firstName: 'Ana',
    lastName: 'Pérez',
    seniority: Seniority.senior1,
    area: 'Desarrollo',
    email: 'ana@example.com',
  );

  Course course(String name, CourseCategory type, double entry) => Course(
    id: name,
    name: name,
    category: type,
    courseArea: 'General',
    instructorEmployeeId: '',
    workloadHours: entry,
  );

  CrmTimeEntry timeEntry(
    String courseName,
    double hours, {
    String? classification,
  }) => CrmTimeEntry(
    id: '$courseName-$hours-$classification',
    courseName: courseName,
    employeeId: '100',
    date: DateTime(2026, 5, 10),
    hours: hours,
    kind: TimeEntryKind.taken,
    classification: classification,
  );

  LmsCertification completed(String courseName) => LmsCertification(
    employeeId: '100',
    courseName: courseName,
    isCompleted: true,
    completedAt: DateTime(2026, 5, 20),
  );

  EmployeeCompliance calculate({
    List<Course> courses = const [],
    required List<CrmTimeEntry> timeEntries,
    List<LmsCertification> certifications = const [],
  }) => const ComplianceService()
      .calculateComplianceGlobal(
        employees: [employee],
        courses: courses,
        timeEntries: timeEntries,
        lmsCertifications: certifications,
      )
      .single;

  test('Libres / exploración del CRM es válida sin LMS ni catálogo', () {
    final result = calculate(
      timeEntries: [
        timeEntry('Curso libre', 5, classification: 'Libres / exploración'),
      ],
    );

    expect(result.creditedHours[CourseCategory.exploration], 5);
    expect(result.declaredHours[CourseCategory.exploration], 5);
  });

  test('Dictado de capacitaciones del CRM es válido y se marca dictado', () {
    final teaching = timeEntry(
      'Taller interno',
      3,
      classification: 'Dictado de capacitaciones',
    );
    final result = calculate(timeEntries: [teaching]);

    expect(teaching.isTaught, isTrue);
    expect(result.creditedHours[CourseCategory.teaching], 3);
    expect(result.declaredHours[CourseCategory.teaching], 3);
  });

  test('la Clasificación se reconoce sin tildes ni mayúsculas', () {
    final result = calculate(
      timeEntries: [
        timeEntry('A', 1, classification: '  LIBRES / EXPLORACION '),
        timeEntry('B', 2, classification: 'dictado de capacitaciones'),
      ],
    );

    expect(result.creditedHours[CourseCategory.exploration], 1);
    expect(result.creditedHours[CourseCategory.teaching], 2);
  });

  test('reconoce las Clasificaciones tal como vienen del CRM', () {
    expect(
      CourseCategory.fromText('Habilidades de Negocio y Herramientas'),
      CourseCategory.businessSkills,
    );
    expect(
      CourseCategory.fromText('Habilidades Blandas'),
      CourseCategory.softSkills,
    );
    expect(
      CourseCategory.fromText('Exploracion / Profundizacion'),
      CourseCategory.exploration,
    );
    expect(
      CourseCategory.fromText('Horas de Dictado'),
      CourseCategory.teaching,
    );
    expect(CourseCategory.fromText('Otra cosa'), isNull);

    final result = calculate(
      timeEntries: [
        timeEntry('A', 1, classification: 'Exploracion / Profundizacion'),
        timeEntry('B', 2, classification: 'Horas de Dictado'),
      ],
    );
    expect(result.creditedHours[CourseCategory.exploration], 1);
    expect(result.creditedHours[CourseCategory.teaching], 2);
  });

  test('Negocio declarado en CRM sin finalizar en LMS no suma', () {
    final result = calculate(
      courses: [course('Finanzas', CourseCategory.businessSkills, 8)],
      timeEntries: [
        timeEntry('Finanzas', 5, classification: 'Habilidades de negocio'),
      ],
    );

    expect(result.creditedHours[CourseCategory.businessSkills], 0);
    expect(result.declaredHours[CourseCategory.businessSkills], 5);
  });

  test('curso finalizado en LMS acredita su carga horaria, no la del CRM', () {
    final courses = [
      course('Arquitectura Cloud', CourseCategory.businessSkills, 8),
      course('Liderazgo', CourseCategory.softSkills, 4),
    ];
    final result = calculate(
      courses: courses,
      timeEntries: [timeEntry('Arquitectura Cloud', 1)],
      certifications: [
        completed('Arquitectura Cloud'),
        // Sin ninguna carga en el CRM.
        completed('Liderazgo'),
      ],
    );

    expect(result.creditedHours[CourseCategory.businessSkills], 8);
    expect(result.declaredHours[CourseCategory.businessSkills], 1);
    expect(result.creditedHours[CourseCategory.softSkills], 4);
  });

  test('el cálculo mensual usa solo las finalizaciones y cargas del mes', () {
    List<EmployeeCompliance> month(int number) =>
        const TeamsService().periods.calculateMonthlyCompliance(
          employees: [employee],
          courses: [
            course('Arquitectura Cloud', CourseCategory.businessSkills, 8),
          ],
          timeEntries: [
            timeEntry('Arquitectura Cloud', 1),
            timeEntry('Taller', 2, classification: 'Dictado de capacitaciones'),
          ],
          certifications: [completed('Arquitectura Cloud')],
          year: 2026,
          month: number,
          complianceService: const ComplianceService(),
        );

    // Cargas del 10/05 y finalización del 20/05.
    final may = month(5).single;
    expect(may.creditedHours[CourseCategory.businessSkills], 8);
    expect(may.creditedHours[CourseCategory.teaching], 2);

    final june = month(6).single;
    expect(june.totalCreditedHours, 0);
  });

  test('Libres finalizado en LMS no suma: solo cuenta el CRM', () {
    final result = calculate(
      courses: [course('Laboratorio', CourseCategory.exploration, 8)],
      timeEntries: [
        timeEntry('Laboratorio', 1, classification: 'Libres / exploración'),
      ],
      certifications: [completed('Laboratorio')],
    );

    expect(result.creditedHours[CourseCategory.exploration], 1);
  });

  group('Plan de formación configurable', () {
    // Senior 1 por defecto: 0 negocio, 2 blandas, 2 libres, 4 dictado.
    final sixTeachingHours = TrainingPlan({
      for (final seniority in Seniority.values)
        seniority: seniority == Seniority.senior1
            ? {
                CourseCategory.businessSkills: 0,
                CourseCategory.softSkills: 2,
                CourseCategory.exploration: 2,
                CourseCategory.teaching: 6,
              }
            : TrainingPlanDefaults.hours[seniority]!,
    });
    final fromJune = TrainingPlanHistory([
      TrainingPlanVersion(validFrom: DateTime(2026, 6), plan: sixTeachingHours),
    ]);
    final service = ComplianceService(plans: fromJune);

    test('el objetivo sale de la versión vigente en el mes evaluado', () {
      List<EmployeeCompliance> month(int number) =>
          const TeamsService().periods.calculateMonthlyCompliance(
            employees: [employee],
            courses: const [],
            timeEntries: [
              timeEntry(
                'Taller',
                5,
                classification: 'Dictado de capacitaciones',
              ),
            ],
            certifications: const [],
            year: 2026,
            month: number,
            complianceService: service,
          );

      // Mayo es anterior al cambio: el dictado pedido sigue siendo 4 h.
      final may = month(5).single;
      expect(may.requiredHours[CourseCategory.teaching], 4);
      expect(may.totalRequiredHours, 8);
      expect(may.applicableHours(CourseCategory.teaching), 4);

      // Junio ya usa el plan nuevo: 10 h en total.
      final june = month(6).single;
      expect(june.requiredHours[CourseCategory.teaching], 6);
      expect(june.totalRequiredHours, 10);
    });

    test('el anual suma los objetivos de cada mes con su versión', () {
      final annual = const TeamsService().periods
          .calculateAnnualCompliance(
            employees: [employee],
            courses: const [],
            timeEntries: [
              timeEntry(
                'Taller',
                5,
                classification: 'Dictado de capacitaciones',
              ),
              CrmTimeEntry(
                id: 'junio',
                courseName: 'Taller',
                employeeId: '100',
                date: DateTime(2026, 6, 10),
                hours: 5,
                kind: TimeEntryKind.taken,
                classification: 'Dictado de capacitaciones',
              ),
            ],
            certifications: const [],
            year: 2026,
            complianceService: service,
          )
          .single;

      // Mayo (8 h) + junio (10 h): los dos meses con datos.
      expect(annual.totalRequiredHours, 18);
      expect(annual.requiredHours[CourseCategory.teaching], 10);
      // En el anual mayo ya no topea en 4: suma 5 + 5, contra 10 requeridas.
      expect(annual.creditedHours[CourseCategory.teaching], 10);
      expect(annual.applicableHours(CourseCategory.teaching), 10);
    });

    test('el anual compensa un mes flojo con uno fuerte de la misma '
        'categoría, con tope en el objetivo anual', () {
      CrmTimeEntry teaching(String id, int month, double hours) => CrmTimeEntry(
        id: id,
        courseName: 'Taller',
        employeeId: '100',
        date: DateTime(2026, month, 10),
        hours: hours,
        kind: TimeEntryKind.taken,
        classification: 'Dictado de capacitaciones',
      );
      EmployeeCompliance annual(List<CrmTimeEntry> timeEntries) =>
          const TeamsService().periods
              .calculateAnnualCompliance(
                employees: [employee],
                courses: const [],
                timeEntries: timeEntries,
                certifications: const [],
                year: 2026,
                complianceService: service,
              )
              .single;

      // Junio y julio piden 6 h de dictado: 2 + 10 cubren las 12.
      final compensated = annual([teaching('j', 6, 2), teaching('k', 7, 10)]);
      expect(compensated.applicableHours(CourseCategory.teaching), 12);

      // El excedente no pasa del objetivo anual de la categoría.
      final exceeded = annual([teaching('j', 6, 10), teaching('k', 7, 10)]);
      expect(exceeded.applicableHours(CourseCategory.teaching), 12);
      expect(exceeded.applicableHours(CourseCategory.softSkills), 0);
    });

    test('sin período usa la versión vigente hoy', () {
      final today = DateTime.now();
      final result =
          ComplianceService(
                plans: TrainingPlanHistory([
                  TrainingPlanVersion(
                    validFrom: DateTime(today.year, today.month),
                    plan: sixTeachingHours,
                  ),
                ]),
              )
              .calculateComplianceGlobal(
                employees: [employee],
                courses: const [],
                timeEntries: const [],
                lmsCertifications: const [],
              )
              .single;

      expect(result.requiredHours[CourseCategory.teaching], 6);
    });
  });
}
