import 'dart:convert';

import 'package:app_finnegans/features/courses/data/supabase_courses_repository.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/imports/domain/snapshot_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        'id_curso': '107',
        'nombre': 'ISO 9001',
        'clasificacion': 'habilidadesBlandas',
        'carga_horaria': 2,
        'activo': true,
      },
      {
        'id_curso': '200',
        'nombre': 'Curso discontinuado',
        'clasificacion': 'habilidadesDeNegocio',
        'carga_horaria': 1,
        'activo': true,
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
        final keysOnly = request.url.queryParameters['select'] == 'id_curso';
        return http.Response(
          jsonEncode([
            for (final row in existing)
              keysOnly ? {'id_curso': row['id_curso']} : row,
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

    final result = await const SnapshotSyncService()
        .syncCourseCatalog(SupabaseCoursesRepository(client), [
          _course('30014', ' iso 9001 ', hours: 8),
          _course('30001', 'Administración de accesos'),
        ]);

    final byId = {for (final row in written) row['id_curso']: row};
    expect(byId.keys, unorderedEquals(['107', '30001', '200']));
    // El existente conserva su ID y toma los datos del archivo.
    expect(byId['107']!['carga_horaria'], 8);
    expect(byId['107']!['clasificacion'], 'habilidadesDeNegocio');
    expect(byId['107']!['activo'], isTrue);
    expect(byId['30001']!['activo'], isTrue);
    // El que ya no viene en el archivo se desactiva.
    expect(byId['200']!['activo'], isFalse);
    expect(result.processedRecords, 2);
    expect(result.inserted, 1);
  });
}
