import 'dart:async';
import 'dart:convert';

import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:http/http.dart' as http;

class MoodleCursosApi {
  static const _token = 'c1838bd2db5e4c5fb233c4d6a6f693bb';
  static final Uri _endpoint = Uri.https(
    'academia-test.finneg.com',
    '/webservice/rest/server.php',
  );

  Future<List<Curso>> getCursos() async {
    final uri = _endpoint.replace(
      queryParameters: {
        'wstoken': _token,
        'wsfunction': 'core_course_get_courses',
        'moodlewsrestformat': 'json',
      },
    );
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'Moodle respondió con estado HTTP ${response.statusCode}.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const FormatException('Moodle devolvió una respuesta inválida.');
    }
    return parseCourses(decoded);
  }

  static List<Curso> parseCourses(Object? response) {
    if (response is Map) {
      final message = response['message']?.toString();
      throw FormatException(
        message == null || message.isEmpty
            ? 'Moodle devolvió un error al consultar los cursos.'
            : 'Moodle: $message',
      );
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
