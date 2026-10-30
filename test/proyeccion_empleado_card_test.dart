import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:app_finnegans/presentation/widgets/shared/proyeccion_empleado_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(WidgetTester tester, EmployeeProjection projection) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: EmployeeProjectionCard(projection: projection, year: 2026),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Si no llega, dice qué habilidades reforzar y cuánto', (
    tester,
  ) async {
    // Septiembre: faltan 3 meses.
    await _show(
      tester,
      const EmployeeProjection(
        employeeId: '1',
        cutoffMonth: 9,
        categories: [
          CategoryProjection(
            type: CourseCategory.softSkills,
            accumulated: 10,
            goal: 16,
            projected: 14,
          ),
          CategoryProjection(
            type: CourseCategory.businessSkills,
            accumulated: 8,
            goal: 16,
            projected: 13,
          ),
          CategoryProjection(
            type: CourseCategory.exploration,
            accumulated: 6,
            goal: 8,
            projected: 9,
          ),
        ],
      ),
    );

    expect(find.text('Para llegar a diciembre tiene que reforzar:'), findsOne);
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('proyeccion_falta_businessSkills')),
          )
          .data,
      'Habilidades de negocio · faltan 3.0 h (+1.0 h/mes)',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('proyeccion_falta_softSkills')))
          .data,
      'Habilidades blandas · faltan 2.0 h (+0.7 h/mes)',
    );
    // Libres llega: no se pide reforzarla.
    expect(find.byKey(const Key('proyeccion_falta_exploration')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Si llega, lo dice sin pedir refuerzos', (tester) async {
    await _show(
      tester,
      const EmployeeProjection(
        employeeId: '1',
        cutoffMonth: 9,
        categories: [
          CategoryProjection(
            type: CourseCategory.businessSkills,
            accumulated: 12,
            goal: 16,
            projected: 17,
          ),
        ],
      ),
    );

    expect(
      find.text('Con su tendencia cumple todas las habilidades de su plan.'),
      findsOne,
    );
    expect(find.textContaining('reforzar'), findsNothing);
  });
}
