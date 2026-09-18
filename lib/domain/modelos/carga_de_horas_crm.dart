enum TipoCargaDeHoras { tomada, dictada }

class CargaDeHorasCRM {
  final String id;
  final String cursoId;
  final String empleadoLegajo;
  final DateTime fecha;
  final double horasTotales;
  final TipoCargaDeHoras tipo;

  const CargaDeHorasCRM({
    required this.id,
    required this.cursoId,
    required this.empleadoLegajo,
    required this.fecha,
    required this.horasTotales,
    required this.tipo,
  });

  bool get esDictada => tipo == TipoCargaDeHoras.dictada;

  Map<String, dynamic> toJson() => {
    'id': id,
    'cursoId': cursoId,
    'empleadoLegajo': empleadoLegajo,
    'fecha': fecha.toIso8601String(),
    'horasTotales': horasTotales,
    'tipo': tipo.name,
  };

  factory CargaDeHorasCRM.fromJson(
    Map<String, dynamic> json,
  ) => CargaDeHorasCRM(
    id: json['id']?.toString() ?? '',
    cursoId: json['cursoId']?.toString() ?? '',
    empleadoLegajo: json['empleadoLegajo']?.toString() ?? '',
    fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
    horasTotales: double.tryParse(json['horasTotales']?.toString() ?? '') ?? 0,
    tipo: json['tipo']?.toString() == TipoCargaDeHoras.dictada.name
        ? TipoCargaDeHoras.dictada
        : TipoCargaDeHoras.tomada,
  );
}
