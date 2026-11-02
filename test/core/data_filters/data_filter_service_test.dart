import 'package:app_finnegans/core/data_filters/domain/data_filter.dart';
import 'package:app_finnegans/core/data_filters/domain/data_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _rows = [
  FilterRow({'area': 'Servicios', 'team': 'Soporte'}),
  FilterRow({'area': 'Servicios', 'team': 'Mesa'}),
  FilterRow({'area': 'Producto', 'team': 'Core'}),
];

void main() {
  const service = DataFilterService();

  group('matches', () {
    const row = FilterRow({'area': 'Servicios', 'team': 'Soporte'});

    test('Sin selección, o con una dimensión vacía, todo coincide', () {
      expect(service.matches(const {}, row), isTrue);
      expect(service.matches(const {'area': {}}, row), isTrue);
    });

    test('Dentro de una dimensión alcanza con uno de los valores', () {
      expect(
        service.matches(const {
          'area': {'Producto', 'Servicios'},
        }, row),
        isTrue,
      );
    });

    test('Entre dimensiones tienen que coincidir todas', () {
      expect(
        service.matches(const {
          'area': {'Servicios'},
          'team': {'Mesa'},
        }, row),
        isFalse,
      );
    });

    test('Una fila sin esa dimensión no coincide', () {
      expect(
        service.matches(const {
          'seniority': {'Senior 1'},
        }, row),
        isFalse,
      );
    });
  });

  group('withValues', () {
    const current = {
      'area': {'Servicios'},
      'team': {'Soporte'},
    };

    test('Reemplaza los valores de la dimensión y conserva las demás', () {
      final next = service.withValues(current, 'team', {'Mesa', 'Core'});

      expect(next, {
        'area': {'Servicios'},
        'team': {'Mesa', 'Core'},
      });
    });

    test('Un conjunto vacío quita la dimensión', () {
      expect(service.withValues(current, 'team', {}), {
        'area': {'Servicios'},
      });
    });

    test('El resultado no se puede modificar', () {
      final next = service.withValues(current, 'team', {'Mesa'});

      expect(() => next['otra'] = {}, throwsUnsupportedError);
      expect(() => next['team']!.add('Core'), throwsUnsupportedError);
    });
  });

  test('labelFor usa la etiqueta y, si no hay, el valor', () {
    const options = DataFilterOptions(
      values: ['C1', 'C2'],
      incompatibleValues: {},
      labels: {'C1': 'Oratoria'},
    );

    expect(service.labelFor(options, 'C1'), 'Oratoria');
    expect(service.labelFor(options, 'C2'), 'C2');
  });

  group('cascade', () {
    test('Sin selección ofrece todos los valores de cada dimensión', () {
      final options = service.cascade(_rows, const {});

      expect(options['area']!.values, ['Producto', 'Servicios']);
      expect(options['team']!.values, ['Core', 'Mesa', 'Soporte']);
      expect(options['area']!.incompatibleValues, isEmpty);
    });

    test('Las demás dimensiones se acotan por la selección', () {
      final options = service.cascade(_rows, const {
        'area': {'Servicios'},
      });

      expect(options['team']!.values, ['Mesa', 'Soporte']);
    });

    test('La dimensión seleccionada sigue ofreciendo sus hermanos', () {
      final options = service.cascade(_rows, const {
        'area': {'Servicios'},
      });

      expect(options['area']!.values, ['Producto', 'Servicios']);
    });

    test('Un valor elegido que ya no es compatible se marca', () {
      final options = service.cascade(_rows, const {
        'area': {'Servicios'},
        'team': {'Core'},
      });

      expect(options['team']!.values, ['Core', 'Mesa', 'Soporte']);
      expect(options['team']!.incompatibleValues, {'Core'});
      expect(options['area']!.values, ['Producto', 'Servicios']);
      expect(options['area']!.incompatibleValues, {'Servicios'});
    });

    test('Los valores en blanco no son opciones', () {
      final options = service.cascade(const [
        FilterRow({'area': 'Servicios', 'team': '  '}),
      ], const {});

      expect(options['area']!.values, ['Servicios']);
      expect(options.containsKey('team'), isFalse);
    });

    test('Las opciones se ordenan por etiqueta', () {
      final options = service.cascade(const [
        FilterRow({'course': 'C1'}, labels: {'course': 'Zoologia'}),
        FilterRow({'course': 'C2'}, labels: {'course': 'Algebra'}),
        FilterRow({'course': 'C3'}, labels: {'course': 'Excel'}),
      ], const {});

      expect(options['course']!.values, ['C2', 'C3', 'C1']);
      expect(options['course']!.labels['C1'], 'Zoologia');
    });

    test('Una selección sin filas conserva su etiqueta', () {
      final options = service.cascade(
        const [
          FilterRow({'course': 'C1'}, labels: {'course': 'Oratoria'}),
        ],
        const {
          'course': {'C9'},
        },
        selectedLabels: const {
          'course': {'C9': 'Curso dado de baja'},
        },
      );

      expect(options['course']!.values, contains('C9'));
      expect(options['course']!.incompatibleValues, {'C9'});
      expect(service.labelFor(options['course']!, 'C9'), 'Curso dado de baja');
      expect(service.labelFor(options['course']!, 'C1'), 'Oratoria');
    });

    test('Con dos etiquetas para un valor, gana la de la primera fila', () {
      final options = service.cascade(const [
        FilterRow({'course': 'C1'}, labels: {'course': 'Oratoria'}),
        FilterRow({'course': 'C1'}, labels: {'course': 'Oratoria (vieja)'}),
      ], const {});

      expect(options['course']!.labels['C1'], 'Oratoria');
    });
  });
}
