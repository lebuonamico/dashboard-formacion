import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/core/period/domain/period_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = PeriodService();

  group('contains', () {
    test('Sin año ni mes, toda fecha entra', () {
      expect(service.contains(DateTime(1999, 1, 1)), isTrue);
    });

    test('Con año solo, entra cualquier mes de ese año', () {
      expect(service.contains(DateTime(2026, 1, 1), year: 2026), isTrue);
      expect(
        service.contains(DateTime(2026, 12, 31, 23, 59), year: 2026),
        isTrue,
      );
      expect(
        service.contains(DateTime(2025, 12, 31, 23, 59), year: 2026),
        isFalse,
      );
      expect(service.contains(DateTime(2027, 1, 1), year: 2026), isFalse);
    });

    test('Con mes solo, entra ese mes de cualquier año', () {
      expect(service.contains(DateTime(2024, 7, 10), month: 7), isTrue);
      expect(service.contains(DateTime(2026, 8, 1), month: 7), isFalse);
    });

    test('Con año y mes, exige los dos', () {
      expect(
        service.contains(DateTime(2026, 7, 15), year: 2026, month: 7),
        isTrue,
      );
      expect(
        service.contains(DateTime(2025, 7, 15), year: 2026, month: 7),
        isFalse,
      );
      expect(
        service.contains(DateTime(2026, 6, 15), year: 2026, month: 7),
        isFalse,
      );
    });
  });

  group('containsInPeriod', () {
    test('Mensual: del primer al último instante del mes', () {
      const july = PeriodFilter(
        scope: PeriodScope.monthly,
        month: 7,
        year: 2026,
      );

      expect(service.containsInPeriod(july, DateTime(2026, 7, 1)), isTrue);
      expect(
        service.containsInPeriod(july, DateTime(2026, 7, 31, 23, 59, 59)),
        isTrue,
      );
      expect(
        service.containsInPeriod(july, DateTime(2026, 6, 30, 23, 59, 59)),
        isFalse,
      );
      expect(service.containsInPeriod(july, DateTime(2026, 8, 1)), isFalse);
      expect(service.containsInPeriod(july, DateTime(2025, 7, 15)), isFalse);
    });

    test('Anual: todo el año, sin mirar el mes del filtro', () {
      const year = PeriodFilter(
        scope: PeriodScope.annual,
        month: 7,
        year: 2026,
      );

      expect(service.containsInPeriod(year, DateTime(2026, 1, 1)), isTrue);
      expect(
        service.containsInPeriod(year, DateTime(2026, 12, 31, 23, 59)),
        isTrue,
      );
      expect(
        service.containsInPeriod(year, DateTime(2025, 12, 31, 23, 59)),
        isFalse,
      );
      expect(service.containsInPeriod(year, DateTime(2027, 1, 1)), isFalse);
    });

    test('isAnnual sigue el alcance del filtro', () {
      expect(
        service.isAnnual(
          const PeriodFilter(scope: PeriodScope.annual, month: 1, year: 2026),
        ),
        isTrue,
      );
      expect(
        service.isAnnual(
          const PeriodFilter(scope: PeriodScope.monthly, month: 1, year: 2026),
        ),
        isFalse,
      );
    });
  });
}
