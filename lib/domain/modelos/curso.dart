import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class Curso {
  final String id;
  final String nombre;
  final TipoCurso tipo;
  final String areaCurso;
  final String instructorLegajo; // Empleado que dicta
  final double cargaHorariaHs;

  Curso({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.areaCurso,
    required this.instructorLegajo,
    required this.cargaHorariaHs,
  });
}