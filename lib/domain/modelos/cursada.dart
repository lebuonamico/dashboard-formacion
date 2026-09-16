class Cursada {
  final String id;
  final String cursoId;
  final String empleadoLegajo; // Alumno que tomó la clase
  final DateTime fecha;

  Cursada({
    required this.id,
    required this.cursoId,
    required this.empleadoLegajo,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cursoId': cursoId,
        'empleadoLegajo': empleadoLegajo,
        'fecha': fecha.toIso8601String(),
      };

  factory Cursada.fromJson(Map<String, dynamic> json) => Cursada(
        id: json['id']?.toString() ?? '',
        cursoId: json['cursoId']?.toString() ?? '',
        empleadoLegajo: json['empleadoLegajo']?.toString() ?? '',
        fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      );
}