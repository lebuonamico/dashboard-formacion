import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class Curso {
  final String id;
  final String nombre;
  final TipoCurso clasificacion;
  final String areaCurso;
  final String instructorLegajo; // Empleado que dicta
  final double cargaHorariaHs;
  final bool activo;

  Curso({
    required this.id,
    required this.nombre,
    required this.clasificacion,
    required this.areaCurso,
    required this.instructorLegajo,
    required this.cargaHorariaHs,
    this.activo = true,
  });

  // La clasificación histórica se conserva para CRM y cumplimiento.
  TipoCurso? get clasificacionLms => switch (clasificacion) {
    TipoCurso.habilidadesDeNegocio ||
    TipoCurso.habilidadesBlandas => clasificacion,
    _ => null,
  };

  Curso copyWith({String? id, bool? activo}) => Curso(
    id: id ?? this.id,
    nombre: nombre,
    clasificacion: clasificacion,
    areaCurso: areaCurso,
    instructorLegajo: instructorLegajo,
    cargaHorariaHs: cargaHorariaHs,
    activo: activo ?? this.activo,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'clasificacion': clasificacion.name,
        'areaCurso': areaCurso,
        'instructorLegajo': instructorLegajo,
        'cargaHorariaHs': cargaHorariaHs,
        'activo': activo,
      };

  factory Curso.fromJson(Map<String, dynamic> json) => Curso(
        id: json['id']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        clasificacion: TipoCurso.values.firstWhere(
          (tipo) => tipo.name == json['clasificacion'],
          orElse: () => TipoCurso.libresExploracion,
        ),
        areaCurso: json['areaCurso']?.toString() ?? '',
        instructorLegajo: json['instructorLegajo']?.toString() ?? '',
        cargaHorariaHs: double.tryParse(json['cargaHorariaHs'].toString()) ?? 0,
        activo: json['activo'] as bool? ?? true,
      );
}
