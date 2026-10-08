import 'dart:async';

import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MoodleCursosApi {
  Future<List<Curso>> getCursos() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      throw const FormatException(
        'Iniciá sesión para sincronizar los cursos de Moodle.',
      );
    }
    try {
      final response = await client.functions
          .invoke('moodle-cursos')
          .timeout(const Duration(seconds: 30));
      if (response.status != 200) {
        throw const FormatException('No se pudieron consultar los cursos.');
      }
      return parseCourses(response.data);
    } on FunctionException catch (error) {
      throw FormatException(switch (error.status) {
        401 => 'Iniciá sesión nuevamente para sincronizar los cursos.',
        403 => 'Tu usuario no está autorizado para sincronizar los cursos.',
        _ =>
          'No se pudieron consultar los cursos de Moodle. Intentá nuevamente.',
      });
    }
  }

  static List<Curso> parseCourses(Object? response) {
    if (response is Map) {
      throw const FormatException('No se pudieron consultar los cursos.');
    }
    if (response is! List) {
      throw const FormatException(
        'Moodle devolvió un formato de cursos desconocido.',
      );
    }

    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['id']?.toString() != '1')
        .map((item) {
          final id = item['id']?.toString().trim() ?? '';
          final nombre = item['fullname']?.toString().trim() ?? '';
          if (id.isEmpty || nombre.isEmpty) return null;
          return Curso(
            id: id,
            nombre: nombre,
            tipo: TipoCurso.libresExploracion,
            areaCurso: '',
            instructorLegajo: '',
            cargaHorariaHs: 0,
          );
        })
        .whereType<Curso>()
        .toList();
  }
}
