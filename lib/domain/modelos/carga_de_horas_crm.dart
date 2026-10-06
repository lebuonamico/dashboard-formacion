import 'package:app_finnegans/domain/importacion/valores_importacion.dart';

enum TipoCargaDeHoras { tomada, dictada }

class CargaDeHorasCRM {
  final String? cursoId;
  final String? caso;
  final String? descripcionCurso;
  final String? clasificacion;
  final String? proyecto;
  final String? proyectoItem;
  final String? descripcion;
  final String id;
  final String cursoNombre;
  final String empleadoLegajo;
  final DateTime fecha;
  final double horasTotales;
  final TipoCargaDeHoras tipo;

  const CargaDeHorasCRM({
    this.cursoId,
    this.caso,
    this.descripcionCurso,
    this.clasificacion,
    this.proyecto,
    this.proyectoItem,
    this.descripcion,
    required this.id,
    required this.cursoNombre,
    required this.empleadoLegajo,
    required this.fecha,
    required this.horasTotales,
    required this.tipo,
  });

  bool get esDictada => tipo == TipoCargaDeHoras.dictada;

  Map<String, dynamic> toJson() => {
    'cursoId': cursoId,
    'caso': caso,
    'descripcionCurso': descripcionCurso,
    'clasificacion': clasificacion,
    'proyecto': proyecto,
    'proyectoItem': proyectoItem,
    'descripcion': descripcion,
    'id': id,
    'cursoNombre': cursoNombre,
    'empleadoLegajo': empleadoLegajo,
    'fecha': fecha.toIso8601String(),
    'horasTotales': horasTotales,
    'tipo': tipo.name,
  };

  factory CargaDeHorasCRM.fromJson(Map<String, dynamic> json) =>
      CargaDeHorasCRM(
        cursoId: json['cursoId']?.toString(),
        caso: json['caso']?.toString(),
        descripcionCurso: json['descripcionCurso']?.toString(),
        clasificacion: json['clasificacion']?.toString(),
        proyecto: json['proyecto']?.toString(),
        proyectoItem: json['proyectoItem']?.toString(),
        descripcion: json['descripcion']?.toString(),
        id: json['id']?.toString() ?? '',
        cursoNombre: json['cursoNombre']?.toString() ?? '',
        empleadoLegajo: json['empleadoLegajo']?.toString() ?? '',
        fecha: fechaObligatoria(json['fecha']?.toString() ?? ''),
        horasTotales:
            double.tryParse(json['horasTotales']?.toString() ?? '') ?? 0,
        tipo: json['tipo']?.toString() == TipoCargaDeHoras.dictada.name
            ? TipoCargaDeHoras.dictada
            : TipoCargaDeHoras.tomada,
      );
}
