import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/projection/domain/projection_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/projection/domain/projection.dart';

const _business = CourseCategory.businessSkills;
const _softSkills = CourseCategory.softSkills;

/// Cumplimiento de un mes de un colaborador: [hours] válidas sin tope y
/// [required] por categoría.
EmployeeCompliance _month(
  Map<CourseCategory, double> hours,
  Map<CourseCategory, double> required, {
  String employeeId = '1',
  String area = 'SERVICIOS',
  String team = 'SOPORTE',
}) {
  return const EmployeeComplianceService().summarize(
    employee: Employee(
      employeeId: employeeId,
      firstName: 'Ana',
      lastName: 'Pérez',
      seniority: Seniority.senior1,
      area: area,
      email: '$employeeId@finnegans.com',
      team: team,
    ),
    creditedHours: hours,
    declaredHours: hours,
    requiredHours: required,
  );
}

/// Un mes con una sola categoría (Negocio).
EmployeeCompliance _c(
  double hours, {
  double target = 8,
  String id = '1',
  String area = 'SERVICIOS',
  String team = 'SOPORTE',
}) => _month(
  {_business: hours},
  {_business: target},
  employeeId: id,
  area: area,
  team: team,
);

void main() {
  const service = ProjectionService();

  test('Quien recupera un mes flojo con uno fuerte llega', () {
    // Noviembre 0 de 4 y diciembre 8 de 4: 8 de 8 en el año.
    final projection = service.calculate(
      byMonth: {
        11: [_c(0, target: 4)],
        12: [_c(8, target: 4)],
      },
      cutoffMonth: 12,
    )!;

    expect(projection.goal, 8);
    expect(projection.projection, 8);
    expect(projection.arrive, 1);
    expect(projection.status, ProjectionStatus.onTrack);
  });

  test('Las horas no se prestan entre colaboradores', () {
    final projection = service.calculate(
      byMonth: {
        12: [_c(16), _c(0, id: '2')],
      },
      cutoffMonth: 12,
    )!;

    // El excedente del primero no cubre al segundo: (8 + 0) / 2.
    expect(projection.projection, 4);
    expect(projection.goal, 8);
    expect(projection.percentage, 50);
    expect(projection.arrive, 1);
    expect(projection.employeeCount, 2);
    expect(projection.status, ProjectionStatus.atRisk);
  });

  test('El excedente de una categoría no cubre otra', () {
    final projection = service.calculate(
      byMonth: {
        12: [
          _month(
            {_business: 10, _softSkills: 0},
            {_business: 4, _softSkills: 4},
          ),
        ],
      },
      cutoffMonth: 12,
    )!;

    expect(projection.projection, 4);
    expect(projection.goal, 8);
    expect(projection.arrive, 0);
  });

  test('Una tendencia creciente proyecta más que un ritmo plano', () {
    final increasing = service.calculate(
      byMonth: {
        7: [_c(2)],
        8: [_c(4)],
        9: [_c(6)],
      },
      cutoffMonth: 9,
    )!;
    final flat = service.calculate(
      byMonth: {
        7: [_c(4)],
        8: [_c(4)],
        9: [_c(4)],
      },
      cutoffMonth: 9,
    )!;

    // Meta: 3 meses con datos + 3 que faltan, a 8 h.
    expect(increasing.goal, 48);
    // 12 acumuladas + 8, 10 y 12 de la tendencia.
    expect(increasing.projection, closeTo(42, 1e-9));
    expect(increasing.status, ProjectionStatus.reachable);
    expect(flat.projection, closeTo(24, 1e-9));
    expect(flat.status, ProjectionStatus.atRisk);
    expect(flat.adjustment, closeTo(8, 1e-9));
  });

  test('Una tendencia decreciente nunca resta horas', () {
    final projection = service.calculate(
      byMonth: {
        7: [_c(6)],
        8: [_c(4)],
        9: [_c(2)],
      },
      cutoffMonth: 9,
    )!;

    // La tendencia da 0, -2 y -4: se toman como 0.
    expect(projection.projection, closeTo(12, 1e-9));
  });

  test('Los meses sin datos de nadie no cuentan', () {
    final projection = service.calculate(
      byMonth: {
        9: [_c(8)],
      },
      cutoffMonth: 9,
    )!;

    // Solo septiembre y los 3 meses que faltan, a ritmo plano.
    expect(projection.goal, 32);
    expect(projection.projection, 32);
    expect(projection.status, ProjectionStatus.onTrack);
  });

  test('Un mes con datos sin horas del colaborador cuenta como 0', () {
    final projection = service.calculate(
      byMonth: {
        8: [_c(0)],
        9: [_c(8)],
      },
      cutoffMonth: 9,
    )!;

    expect(projection.accumulated, 8);
    expect(projection.goal, 40);
  });

  test('El cumplimiento del mes usa el tope y se compara con el anterior', () {
    final projection = service.calculate(
      byMonth: {
        8: [_c(6), _c(8, id: '2')],
        9: [_c(7), _c(12, id: '2')],
      },
      cutoffMonth: 9,
    )!;

    // Las 12 h del segundo topean en 8 para el mes.
    expect(projection.recentPace, 7.5);
    expect(projection.previousMonthPace, 7);
    expect(projection.variation, 0.5);
    expect(projection.monthCompliance, closeTo(93.75, 1e-9));
  });

  test('Sin mes anterior con datos no hay variación', () {
    final projection = service.calculate(
      byMonth: {
        9: [_c(8)],
      },
      cutoffMonth: 9,
    )!;

    expect(projection.previousMonthPace, isNull);
    expect(projection.variation, isNull);
  });

  group('Por colaborador', () {
    test('Dice cuánto le falta en cada habilidad, la mayor primero', () {
      // Diciembre: 1 de 4 en Negocio, 2 de 4 en Blandas.
      final employee = service
          .projectEmployees(
            byMonth: {
              12: [
                _month(
                  {_business: 1, _softSkills: 2},
                  {_business: 4, _softSkills: 4},
                ),
              ],
            },
            cutoffMonth: 12,
          )
          .single;

      expect(employee.arrives, isFalse);
      expect(employee.missing.map((c) => c.type), [_business, _softSkills]);
      expect(employee.missing.map((c) => c.missing), [3, 2]);
    });

    test('Solo incluye las habilidades que pide su seniority', () {
      final employee = service
          .projectEmployees(
            byMonth: {
              12: [
                _month(
                  {_business: 5, _softSkills: 3},
                  {_business: 4, _softSkills: 0},
                ),
              ],
            },
            cutoffMonth: 12,
          )
          .single;

      expect(employee.categories.map((c) => c.type), [_business]);
      expect(employee.arrives, isTrue);
      expect(employee.missing, isEmpty);
      expect(employee.status, ProjectionStatus.onTrack);
    });

    test('Usa todo su historial y proyecta los meses que faltan', () {
      final employee = service
          .projectEmployees(
            byMonth: {
              8: [_c(4), _c(8, id: '2')],
              9: [_c(4), _c(8, id: '2')],
            },
            cutoffMonth: 9,
          )
          .firstWhere((e) => e.employeeId == '1');
      final business = employee.categories.single;

      expect(business.accumulated, 8);
      expect(business.goal, 40);
      // Ritmo plano de 4 h en los 3 meses que faltan.
      expect(business.projected, closeTo(20, 1e-9));
      expect(business.missing, closeTo(20, 1e-9));
    });
  });

  group('Variación contra el mes anterior', () {
    test('Sube si el último mes mejora la proyección', () {
      final projection = service.calculate(
        byMonth: {
          8: [_c(4)],
          9: [_c(8)],
        },
        cutoffMonth: 9,
      )!;
      // Agosto: 4 h y 4 meses a 4 h = 20 de 40 (50 %). Septiembre llega.
      expect(projection.previousPercentage, closeTo(50, 1e-9));
      expect(projection.percentage, 100);
      expect(projection.projectionVariation, closeTo(50, 1e-9));
    });

    test('Baja si el último mes empeora la proyección', () {
      final projection = service.calculate(
        byMonth: {
          8: [_c(8)],
          9: [_c(0)],
        },
        cutoffMonth: 9,
      )!;
      expect(projection.projectionVariation, lessThan(0));
    });

    test('Sin mes anterior con datos no hay variación', () {
      final projection = service.calculate(
        byMonth: {
          9: [_c(8)],
        },
        cutoffMonth: 9,
      )!;
      expect(projection.previousPercentage, isNull);
      expect(projection.projectionVariation, isNull);
    });
  });

  test('Sin colaboradores en el mes de corte no hay proyección', () {
    expect(
      service.calculate(
        byMonth: {
          8: [_c(8)],
          9: [],
        },
        cutoffMonth: 9,
      ),
      isNull,
    );
  });

  group('Por sección', () {
    test('Sin área ni equipo proyecta toda la nómina', () {
      final byMonth = {
        8: [_c(4), _c(8, id: '2', team: 'DESARROLLO')],
        9: [_c(6), _c(2, id: '2', team: 'DESARROLLO')],
      };
      final all = service.calculate(byMonth: byMonth, cutoffMonth: 9)!;
      final section = service.calculateForSection(
        byMonth: byMonth,
        cutoffMonth: 9,
      )!;

      expect(section.employeeCount, 2);
      expect(section.percentage, all.percentage);
      expect(section.accumulated, all.accumulated);
    });

    test('Toma a quienes están en la sección en el mes de corte', () {
      final byMonth = {
        9: [_c(8), _c(0, id: '2', team: 'DESARROLLO')],
      };

      final support = service.calculateForSection(
        byMonth: byMonth,
        cutoffMonth: 9,
        team: 'SOPORTE',
      )!;
      final development = service.calculateForSection(
        byMonth: byMonth,
        cutoffMonth: 9,
        team: 'DESARROLLO',
      )!;

      expect(support.employeeCount, 1);
      expect(support.arrive, 1);
      expect(development.employeeCount, 1);
      expect(development.arrive, 0);
    });

    test('Cuenta todo su año, aunque antes estuviera en otro equipo', () {
      final projection = service.calculateForSection(
        byMonth: {
          8: [_c(8, team: 'DESARROLLO'), _c(0, id: '2', team: 'DESARROLLO')],
          9: [_c(8), _c(0, id: '2', team: 'DESARROLLO')],
        },
        cutoffMonth: 9,
        team: 'SOPORTE',
      )!;

      // Agosto en Desarrollo + septiembre en Soporte: 16 de una meta de 40.
      expect(projection.employeeCount, 1);
      expect(projection.accumulated, 16);
      expect(projection.goal, 40);
    });

    test('Compara el área sin espacios ni mayúsculas', () {
      final projection = service.calculateForSection(
        byMonth: {
          9: [_c(8), _c(8, id: '2', area: 'PRODUCTOS')],
        },
        cutoffMonth: 9,
        area: ' servicios ',
      )!;

      expect(projection.employeeCount, 1);
    });

    test('Sin nadie de la sección en el mes de corte no hay proyección', () {
      expect(
        service.calculateForSection(
          byMonth: {
            8: [_c(8, team: 'DESARROLLO')],
            9: [_c(8)],
          },
          cutoffMonth: 9,
          team: 'DESARROLLO',
        ),
        isNull,
      );
    });
  });

  group('Variación del cumplimiento', () {
    test('Compara las horas por persona y el acumulado del año', () {
      final variation = service.variation(
        byMonth: {
          8: [_c(4), _c(8, id: '2')],
          9: [_c(6), _c(12, id: '2')],
        },
        cutoffMonth: 9,
      )!;

      // Septiembre: 6 y 12 topeado en 8 → 7 por persona. Agosto: 6.
      expect(variation.hoursPerPerson, 7);
      expect(variation.previousHoursPerPerson, 6);
      expect(variation.hours, 1);
      // Acumulado: agosto 12 de 16 (75 %); a septiembre 10 + 16 de 32.
      expect(variation.points, closeTo(6.25, 1e-9));
    });

    test('Los puntos usan el último mes con datos; las horas, el anterior', () {
      final variation = service.variation(
        byMonth: {
          7: [_c(8)],
          9: [_c(4)],
        },
        cutoffMonth: 9,
      )!;

      expect(variation.hoursPerPerson, 4);
      expect(variation.previousHoursPerPerson, isNull);
      expect(variation.hours, isNull);
      // Julio 8 de 8 (100 %); a septiembre 12 de 16 (75 %).
      expect(variation.points, closeTo(-25, 1e-9));
    });

    test('Sin mes anterior con datos no hay puntos ni horas de diferencia', () {
      final variation = service.variation(
        byMonth: {
          9: [_c(8)],
        },
        cutoffMonth: 9,
      )!;

      expect(variation.hoursPerPerson, 8);
      expect(variation.points, isNull);
      expect(variation.previousHoursPerPerson, isNull);
      expect(variation.hours, isNull);
    });

    test('Cada mes cuenta a quienes estaban en la sección ese mes', () {
      final variation = service.variation(
        byMonth: {
          8: [_c(8, team: 'DESARROLLO'), _c(2, id: '2')],
          9: [_c(4), _c(8, id: '2', team: 'DESARROLLO')],
        },
        cutoffMonth: 9,
        team: 'soporte',
      )!;

      // Agosto: solo el 2 (2 h). Septiembre: solo el 1 (4 h).
      expect(variation.hoursPerPerson, 4);
      expect(variation.previousHoursPerPerson, 2);
      expect(variation.hours, 2);
      // Agosto 2 de 8 (25 %); a septiembre 2 + 4 de 16 (37,5 %).
      expect(variation.points, closeTo(12.5, 1e-9));
    });

    test('Sin datos de la sección en el mes de corte no hay variación', () {
      final byMonth = {
        8: [_c(8)],
        9: <EmployeeCompliance>[],
      };
      expect(service.variation(byMonth: byMonth, cutoffMonth: 9), isNull);
      expect(
        service.variation(
          byMonth: {
            9: [_c(8)],
          },
          cutoffMonth: 9,
          area: 'PRODUCTOS',
        ),
        isNull,
      );
    });
  });
}
