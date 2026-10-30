import 'dart:convert';

import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/core/data/supabase_repositories.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _mapping = SupabaseTableMapping(
  table: 'cursos',
  conflictFields: ['id'],
  columns: {
    for (final field in [
      'id',
      'nombre',
      'clasificacion',
      'cargaHorariaHs',
      'activo',
    ])
      field: 'col_$field',
  },
);

Course _course(String id, String name, {double hours = 4}) => Course(
  id: id,
  name: name,
  category: CourseCategory.businessSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: hours,
);

void main() {
  test('Sincronizar el catálogo actualiza por nombre los cursos existentes '
      'e inserta los nuevos', () async {
    final existing = [
      {
        'col_id': '107',
        'col_nombre': 'ISO 9001',
        'col_clasificacion': 'habilidadesBlandas',
        'col_cargaHorariaHs': 2,
        'col_activo': true,
      },
      {
        'col_id': '200',
        'col_nombre': 'Curso discontinuado',
        'col_clasificacion': 'habilidadesDeNegocio',
        'col_cargaHorariaHs': 1,
        'col_activo': true,
      },
    ];
    final written = <Map<String, dynamic>>[];
    final client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          written.addAll(
            (jsonDecode(request.body) as List).map(
              (row) => Map<String, dynamic>.from(row as Map),
            ),
          );
          return http.Response('', 201, request: request);
        }
        final keysOnly = request.url.queryParameters['select'] == 'col_id';
        return http.Response(
          jsonEncode([
            for (final row in existing)
              keysOnly ? {'col_id': row['col_id']} : row,
          ]),
          200,
          request: request,
          headers: {
            'content-type': 'application/json',
            'content-range': '0-${existing.length - 1}/${existing.length}',
          },
        );
      }),
    );
    addTearDown(client.dispose);

    final result = await SupabaseCoursesRepository(client, _mapping)
        .syncSnapshotWithResult([
          _course('30014', ' iso 9001 ', hours: 8),
          _course('30001', 'Administración de accesos'),
        ]);

    final byId = {for (final row in written) row['col_id']: row};
    expect(byId.keys, unorderedEquals(['107', '30001', '200']));
    // El existente conserva su ID y toma los datos del archivo.
    expect(byId['107']!['col_cargaHorariaHs'], 8);
    expect(byId['107']!['col_clasificacion'], 'habilidadesDeNegocio');
    expect(byId['107']!['col_activo'], isTrue);
    expect(byId['30001']!['col_activo'], isTrue);
    // El que ya no viene en el archivo se desactiva.
    expect(byId['200']!['col_activo'], isFalse);
    expect(result.processedRecords, 2);
    expect(result.inserted, 1);
  });
}
