import 'dart:convert';

import 'package:app_finnegans/data/supabase/supabase_mapping.dart';
import 'package:app_finnegans/data/supabase/supabase_repositories.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
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

Curso _curso(String id, String nombre, {double horas = 4}) => Curso(
  id: id,
  nombre: nombre,
  clasificacion: TipoCurso.habilidadesDeNegocio,
  areaCurso: '',
  instructorLegajo: '',
  cargaHorariaHs: horas,
);

void main() {
  test(
    'Sincronizar el catálogo actualiza por nombre los cursos existentes '
    'e inserta los nuevos',
    () async {
      final existentes = [
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
      final escritos = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            escritos.addAll(
              (jsonDecode(request.body) as List).map(
                (row) => Map<String, dynamic>.from(row as Map),
              ),
            );
            return http.Response('', 201, request: request);
          }
          final soloClaves = request.url.queryParameters['select'] == 'col_id';
          return http.Response(
            jsonEncode([
              for (final row in existentes)
                soloClaves ? {'col_id': row['col_id']} : row,
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);

      final resultado = await SupabaseCursosRepository(client, _mapping)
          .sincronizarFotoVigenteConResultado([
            _curso('30014', ' iso 9001 ', horas: 8),
            _curso('30001', 'Administración de accesos'),
          ]);

      final porId = {for (final row in escritos) row['col_id']: row};
      expect(porId.keys, unorderedEquals(['107', '30001', '200']));
      // El existente conserva su ID y toma los datos del archivo.
      expect(porId['107']!['col_cargaHorariaHs'], 8);
      expect(porId['107']!['col_clasificacion'], 'habilidadesDeNegocio');
      expect(porId['107']!['col_activo'], isTrue);
      expect(porId['30001']!['col_activo'], isTrue);
      // El que ya no viene en el archivo se desactiva.
      expect(porId['200']!['col_activo'], isFalse);
      expect(resultado.registrosProcesados, 2);
      expect(resultado.insertados, 1);
    },
  );
}
