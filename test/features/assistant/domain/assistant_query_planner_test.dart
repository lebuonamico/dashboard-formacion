import 'package:app_finnegans/features/assistant/domain/assistant_context_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _visible = AssistantPeriod(year: 2026, month: 7);
const _dashboard = AssistantDestination(AssistantModule.dashboard);

const _yearNote =
    'El año no se indicó: se usa 2026, seleccionado en la aplicación.';
const _rangeYearNote =
    'El año no se indicó: el rango comienza en 2026, seleccionado en la aplicación; si cruza diciembre continúa en el año siguiente.';
const _imprecise =
    'Esta consulta temporal necesita precisarse como mes/año o año completo. No se enviaron indicadores de un período diferente.';

AssistantQuery _plan(
  String question, {
  AssistantDestination destination = _dashboard,
}) => AssistantContextService().plan(question, destination, _visible);

List<(int, int, bool)> _periods(AssistantQuery query) => [
  for (final period in query.periods)
    (period.year, period.month, period.annual),
];

void main() {
  group('Períodos de la pregunta', () {
    test('sin mención usa el período visible', () {
      final query = _plan('¿Cómo viene el cumplimiento?');
      expect(_periods(query), [(2026, 7, false)]);
      expect(query.notes, isEmpty);
    });

    test('un mes con nombre y sin año usa el año visible', () {
      final query = _plan('¿Cómo viene el cumplimiento de agosto?');
      expect(_periods(query), [(2026, 8, false)]);
      expect(query.notes, [_yearNote]);
    });

    test('un mes con año no agrega nota', () {
      final query = _plan('¿Cómo cerró agosto de 2025?');
      expect(_periods(query), [(2025, 8, false)]);
      expect(query.notes, isEmpty);
    });

    test('"mes N" y año-mes numérico', () {
      expect(_periods(_plan('¿Cómo fue el mes 3?')), [(2026, 3, false)]);
      expect(_periods(_plan('¿Cómo cerró 2026-07?')), [(2026, 7, false)]);
    });

    test('un mes fuera de 1 a 12 es un error', () {
      expect(
        () => _plan('¿Cómo fue el mes 13?'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Indicá un mes válido entre 1 y 12.',
          ),
        ),
      );
    });

    test('un rango acumula sus meses', () {
      final query = _plan('¿Cuál es el acumulado de julio a septiembre?');
      expect(_periods(query), [
        (2026, 7, false),
        (2026, 8, false),
        (2026, 9, false),
      ]);
      expect(query.accumulated, isTrue);
      expect(query.evolution, isFalse);
      expect(query.notes, [_rangeYearNote]);
    });

    test('un rango que cruza diciembre sigue en el año siguiente', () {
      final query = _plan('¿Cuál es el acumulado de noviembre a febrero?');
      expect(_periods(query), [
        (2026, 11, false),
        (2026, 12, false),
        (2027, 1, false),
        (2027, 2, false),
      ]);
    });

    test('la evolución admite hasta doce meses', () {
      final query = _plan(
        '¿Cuál es la evolución de enero de 2025 a marzo de 2026?',
      );
      expect(query.evolution, isTrue);
      expect(query.periods, isEmpty);
      expect(query.notes, [
        'Los rangos y la evolución admiten hasta doce meses consecutivos en orden cronológico. Precisá los meses y años de inicio y fin.',
      ]);
    });

    test('mes pasado y año pasado son relativos al período visible', () {
      final month = _plan('¿Cómo nos fue el mes pasado?');
      expect(_periods(month), [(2026, 6, false)]);
      expect(month.notes, [
        'Mes anterior relativo al período visible, no a la fecha del sistema.',
      ]);

      final year = _plan('¿Cómo nos fue el año pasado?');
      expect(_periods(year), [(2025, 7, true)]);
      expect(year.notes, [
        'Año anterior relativo al año seleccionado en la aplicación.',
      ]);
    });

    test('trimestres y semanas piden precisar el período', () {
      for (final question in ['¿Cómo viene el trimestre?', '¿Y esta semana?']) {
        final query = _plan(question);
        expect(query.periods, isEmpty, reason: question);
        expect(query.notes, [_imprecise], reason: question);
      }
    });

    test('dos rangos distintos no se mezclan', () {
      final query = _plan('Compará de enero a marzo y de julio a septiembre');
      expect(query.periods, isEmpty);
      expect(query.notes, [
        'Se identificaron varios rangos diferentes. Indicá un solo rango de inicio a fin; no se mezclaron sus períodos ni se usó el visible.',
      ]);
    });

    test('más de tres períodos no se envían', () {
      final query = _plan('Compará enero, marzo, mayo y julio');
      expect(query.periods, isEmpty);
      expect(query.notes, [
        _yearNote,
        'Las comparaciones detalladas admiten hasta tres períodos por consulta. No se sustituyeron por el período visible.',
      ]);
    });

    test('un mes y el acumulado anual van en bloques separados', () {
      final query = _plan('¿Cómo viene julio y el acumulado anual?');
      expect(_periods(query), [(2026, 7, false), (2026, 7, true)]);
      expect(query.notes, [
        _yearNote,
        'Cada bloque corresponde a su período. No fusionar meses ni deducir un acumulado del rango. La aplicación dispone de acumulados anuales; usar solo los incluidos en esta consulta.',
      ]);
    });

    test('anual y mensual sin precisar no se envían', () {
      final query = _plan('¿Cómo viene julio y lo anual?');
      expect(query.periods, isEmpty);
      expect(query.notes, [
        _yearNote,
        'Se pidió simultáneamente un análisis anual y mensual. Precisá el alcance; no se enviaron indicadores de otro período.',
      ]);
    });
  });

  group('Tema de la pregunta', () {
    test('por palabras de la pregunta', () {
      expect(
        _plan('¿Cómo importo el archivo de nómina?').theme,
        AssistantTopic.import,
      );
      expect(
        _plan('¿Qué significa cumplimiento?').theme,
        AssistantTopic.conceptual,
      );
      expect(_plan('¿Qué cursos me recomendás?').theme, AssistantTopic.courses);
      expect(_plan('¿Cómo vienen las áreas?').theme, AssistantTopic.areas);
      expect(
        _plan('¿Qué equipos están en riesgo?').theme,
        AssistantTopic.teams,
      );
      expect(
        _plan('¿Cómo viene la persona seleccionada?').theme,
        AssistantTopic.person,
      );
    });

    test('por la pantalla cuando la pregunta no lo dice', () {
      AssistantTopic topic(AssistantDestination destination) =>
          _plan('¿Cómo viene?', destination: destination).theme;

      expect(topic(_dashboard), AssistantTopic.general);
      expect(
        topic(const AssistantDestination(AssistantModule.areas)),
        AssistantTopic.areas,
      );
      expect(
        topic(const AssistantDestination(AssistantModule.teamDetail)),
        AssistantTopic.teams,
      );
      expect(
        topic(const AssistantDestination(AssistantModule.people)),
        AssistantTopic.person,
      );
      expect(
        topic(const AssistantDestination(AssistantModule.courses)),
        AssistantTopic.courses,
      );
      expect(
        topic(const AssistantDestination(AssistantModule.settings)),
        AssistantTopic.import,
      );
      expect(
        topic(const AssistantDestination(AssistantModule.others)),
        AssistantTopic.general,
      );
      expect(
        topic(
          const AssistantDestination(
            AssistantModule.dashboard,
            employeeId: 'EMP-001',
          ),
        ),
        AssistantTopic.person,
      );
    });

    test('el acumulado del cumplimiento es general', () {
      final query = _plan(
        '¿Qué significa el cumplimiento acumulado de julio a agosto?',
      );
      expect(query.theme, AssistantTopic.general);
      expect(query.accumulated, isTrue);
    });

    test('solo totales cuando se pregunta cuántos, sin pedir cuáles', () {
      final service = AssistantContextService();
      expect(service.totalsOnly('¿Cuántos equipos hay?'), isTrue);
      expect(service.totalsOnly('¿Cuántos equipos hay y cuáles?'), isFalse);
      expect(service.totalsOnly('¿Qué equipos hay?'), isFalse);
    });
  });
}
