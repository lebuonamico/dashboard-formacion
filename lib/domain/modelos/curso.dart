import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class Curso {
  final String id;
  final String nombre;
  final TipoCurso tipo;
  final String areaCurso;
  final String instructorLegajo; // Empleado que dicta
  final double cargaHorariaHs;
  final bool activo;

  Curso({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.areaCurso,
    required this.instructorLegajo,
    required this.cargaHorariaHs,
    this.activo = true,
  });

  Curso copyWith({bool? activo}) => Curso(
    id: id,
    nombre: nombre,
    tipo: tipo,
    areaCurso: areaCurso,
    instructorLegajo: instructorLegajo,
    cargaHorariaHs: cargaHorariaHs,
    activo: activo ?? this.activo,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo.name,
        'areaCurso': areaCurso,
        'instructorLegajo': instructorLegajo,
        'cargaHorariaHs': cargaHorariaHs,
        'activo': activo,
      };

  factory Curso.fromJson(Map<String, dynamic> json) => Curso(
        id: json['id']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        tipo: TipoCurso.values.firstWhere(
          (tipo) => tipo.name == json['tipo'],
          orElse: () => TipoCurso.libresExploracion,
        ),
        areaCurso: json['areaCurso']?.toString() ?? '',
        instructorLegajo: json['instructorLegajo']?.toString() ?? '',
        cargaHorariaHs: double.tryParse(json['cargaHorariaHs'].toString()) ?? 0,
        activo: json['activo'] as bool? ?? true,
      );
}
