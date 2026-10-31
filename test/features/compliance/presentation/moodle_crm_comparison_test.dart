import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/compliance/presentation/widgets/moodle_crm_comparison_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/compliance/domain/moodle_crm_comparison_service.dart';

EmployeeCompliance _c({
  required Map<CourseCategory, double> moodle,
  required Map<CourseCategory, double> crm,
  String employeeId = '1',
}) {
  return const EmployeeComplianceService().summarize(
    employee: Employee(
      employeeId: employeeId,
      firstName: 'Ana',
      lastName: 'Pérez',
      seniority: Seniority.senior1,
      area: 'SERVICIOS',
      email: '$employeeId@finnegans.com',
      team: 'SOPORTE',
    ),
    creditedHours: moodle,
    declaredHours: crm,
    requiredHours: {for (final type in CourseCategory.values) type: 4},
  );
}

final _items = [
  _c(
    moodle: {
      CourseCategory.businessSkills: 8,
      CourseCategory.softSkills: 2,
      // Libres válidas vienen del CRM: no son horas de Moodle.
      CourseCategory.exploration: 3,
    },
    crm: {
      CourseCategory.businessSkills: 10,
      CourseCategory.softSkills: 4,
      CourseCategory.exploration: 3,
      CourseCategory.teaching: 5,
    },
  ),
  _c(
    employeeId: '2',
    moodle: {CourseCategory.businessSkills: 4},
    crm: {CourseCategory.businessSkills: 2},
  ),
];

void main() {
  test('Suma Moodle solo en Negocio y Blandas y CRM en las 4', () {
    final comparison = const MoodleCrmComparisonService().compare(_items);

    expect(comparison.moodle, {
      CourseCategory.businessSkills: 12,
      CourseCategory.softSkills: 2,
    });
    expect(comparison.moodleComparable, 14);
    expect(comparison.crmComparable, 16);
    expect(comparison.crmTotal, 24);
  });

  test('La diferencia de las comparables es CRM menos Moodle', () {
    final comparison = const MoodleCrmComparisonService().compare(_items);

    expect(comparison.differenceComparable, 2);
    expect(comparison.percentageDifference, closeTo(14.29, 0.01));
    expect(comparison.match, isFalse);
  });

  test('Sin horas en Moodle no hay porcentaje, y menos de 0.05 h coincide', () {
    final crmOnly = const MoodleCrmComparisonService().compare([
      _c(moodle: const {}, crm: {CourseCategory.softSkills: 3}),
    ]);
    expect(crmOnly.percentageDifference, isNull);
    expect(crmOnly.match, isFalse);

    final equal = const MoodleCrmComparisonService().compare([
      _c(
        moodle: {CourseCategory.businessSkills: 4},
        crm: {CourseCategory.businessSkills: 4.04},
      ),
    ]);
    expect(equal.match, isTrue);
  });

  for (final width in [1200.0, 500.0]) {
    testWidgets('Las cards se muestran sin desbordes a $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoodleCrmComparisonCards(complianceList: _items),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('comparacion_comparables')), findsOne);
      expect(find.byKey(const Key('comparacion_total')), findsOne);
      // Moodle solo aparece en la comparación; la otra card es solo CRM.
      expect(find.text('14.0 h'), findsOne);
      // Negocio es 12 de las 24 h de CRM.
      expect(find.text('Negocio\n50%'), findsOne);
      expect(find.text('16.0 h'), findsOne);
      expect(find.text('24.0 h'), findsOne);
      expect(find.textContaining('CRM registra 2.0 h más'), findsOne);
      expect(tester.takeException(), isNull);
    });
  }
}
