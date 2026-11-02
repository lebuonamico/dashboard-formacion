import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/imports/data/course_catalog_file_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/spreadsheet_fixtures.dart';

final _parser = CourseCatalogFileParser();

Matcher _rejects(String message) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

void main() {
  const header = 'idCurso,NombreCurso,Clasificacion,CargaHoraria';

  test('lee el catálogo con área e instructor vacíos y activo', () {
    final course = _parser
        .parse(
          csvFile(
            '$header\n107, Excel avanzado ,Habilidades de negocio,"4,5"\n',
          ),
        )
        .single;

    expect(course.id, '107');
    expect(course.name, 'Excel avanzado');
    expect(course.category, CourseCategory.businessSkills);
    expect(course.workloadHours, 4.5);
    expect(course.courseArea, isEmpty);
    expect(course.instructorEmployeeId, isEmpty);
    expect(course.isActive, isTrue);
  });

  group('Alias de encabezado', () {
    final columns = {
      'ID': (CourseCatalogFileParser.idAliases, 'idcurso'),
      'nombre': (CourseCatalogFileParser.nameAliases, 'nombrecurso'),
      'tipo': (CourseCatalogFileParser.categoryAliases, 'clasificacion'),
      'carga horaria': (
        CourseCatalogFileParser.workloadHoursAliases,
        'cargahoraria',
      ),
    };

    for (final MapEntry(key: field, value: (aliases, standard))
        in columns.entries) {
      for (final alias in aliases) {
        test('$field desde "$alias"', () {
          final headers = [
            for (final (_, other) in columns.values)
              other == standard ? alias : other,
          ];
          final course = _parser
              .parse(
                csvFile(
                  '${headers.join(',')}\n107,Excel,Habilidades blandas,4\n',
                ),
              )
              .single;

          expect(course.id, '107');
          expect(course.name, 'Excel');
          expect(course.category, CourseCategory.softSkills);
          expect(course.workloadHours, 4);
        });
      }
    }
  });

  test('reconoce las categorías por texto parcial', () {
    final courses = _parser.parse(
      csvFile(
        '$header\n'
        '1,A,Habilidades de Negocio y Herramientas,1\n'
        '2,B,Soft skills,1\n'
        '3,C,Horas de Dictado,1\n'
        '4,D,Exploracion / Profundizacion,1\n',
      ),
    );

    expect(courses.map((course) => course.category), [
      CourseCategory.businessSkills,
      CourseCategory.softSkills,
      CourseCategory.teaching,
      CourseCategory.exploration,
    ]);
  });

  test('encuentra el encabezado debajo de los títulos y suma las hojas', () {
    final courses = _parser.parse(
      xlsxFile({
        'Negocio': [
          ['Catálogo 2026'],
          [],
          ['ID', 'Nombre', 'Tipo', 'Horas'],
          ['1', 'Excel', 'Negocio', 4],
        ],
        'Blandas': [
          ['ID', 'Nombre', 'Tipo', 'Horas'],
          ['2', 'Oratoria', 'Blandas', 2.5],
          ['2', 'Oratoria', 'Blandas', 2.5],
        ],
      }),
    );

    expect(courses.map((course) => course.id), ['1', '2', '2']);
    expect(courses.last.workloadHours, 2.5);
  });

  test('el encabezado más abajo de la fila 15 no se reconoce', () {
    expect(
      () => _parser.parse(
        csvFile(
          '${List.filled(15, 'Título,,,').join('\n')}\n$header\n1,A,Negocio,1\n',
        ),
      ),
      _rejects(
        'No se encontraron cursos con encabezados válidos en la hoja "CSV".',
      ),
    );
  });

  group('Rechazos que cortan la importación', () {
    void expectRejected(String csv, String message) =>
        expect(() => _parser.parse(csvFile(csv)), _rejects(message));

    test('una hoja sin encabezados de cursos', () {
      expectRejected(
        'Columna incorrecta\r\nDato\r\n',
        'No se encontraron cursos con encabezados válidos en la hoja "CSV". No se sincronizó el catálogo.',
      );
    });

    test('falta una columna obligatoria', () {
      expectRejected(
        'id,nombre,horas\n1,A,4\n',
        'Faltan columnas obligatorias de ID, nombre, clasificación o carga horaria en la hoja "CSV".',
      );
    });

    test('encabezado duplicado', () {
      expectRejected(
        '$header,Nombre curso\n1,A,Negocio,1,B\n',
        'Encabezado duplicado "nombrecurso" en la hoja "CSV".',
      );
    });

    test('datos sin encabezado o faltantes', () {
      expectRejected(
        '$header\n1,A,Negocio,1,extra\n',
        'Hay datos sin encabezado de columna en hoja "CSV", fila 2.',
      );
      expectRejected(
        '$header\n1,A,Negocio\n',
        'Faltan datos obligatorios del curso en hoja "CSV", fila 2.',
      );
      expectRejected(
        '$header\n,A,Negocio,1\n',
        'Falta el ID o nombre del curso en hoja "CSV", fila 2.',
      );
    });

    test('carga horaria negativa o no numérica', () {
      expectRejected(
        '$header\n1,A,Negocio,-1\n',
        'Carga horaria inválida en hoja "CSV", fila 2: "-1".',
      );
      expectRejected(
        '$header\n1,A,Negocio,cuatro\n',
        'Carga horaria inválida en hoja "CSV", fila 2: "cuatro".',
      );
    });

    test('clasificación irreconocible', () {
      expectRejected(
        '$header\n1,A,Marketing,1\n',
        'Clasificación inválida en hoja "CSV", fila 2: "Marketing".',
      );
    });

    test('ID repetido con otros datos', () {
      expectRejected(
        '$header\n1,A,Negocio,1\n1,A,Negocio,2\n',
        'El ID de curso "1" tiene datos contradictorios en hoja "CSV", fila 3.',
      );
    });

    test('un archivo sin cursos', () {
      expectRejected(
        '$header\n',
        'No se encontraron cursos. Verificá las columnas de ID y nombre.',
      );
    });
  });
}
