class CertificacionMoodle {
  final String legajo;
  final String cursoNombre;
  final bool finalizoCurso;
  final double cargaEstimada;
  final DateTime? fechaFinalizacion;

  const CertificacionMoodle({
    required this.legajo,
    required this.cursoNombre,
    required this.finalizoCurso,
    required this.cargaEstimada,
    this.fechaFinalizacion,
  });

  Map<String, dynamic> toJson() => {
    'legajo': legajo,
    'cursoNombre': cursoNombre,
    'finalizoCurso': finalizoCurso,
    'cargaEstimada': cargaEstimada,
    'fechaFinalizacion': fechaFinalizacion?.toIso8601String(),
  };

  factory CertificacionMoodle.fromJson(Map<String, dynamic> json) {
    final finalizo = json['finalizoCurso'];
    return CertificacionMoodle(
      legajo: json['legajo']?.toString() ?? '',
      cursoNombre: json['cursoNombre']?.toString() ?? '',
      finalizoCurso: finalizo == true || finalizo?.toString() == 'true',
      cargaEstimada:
          double.tryParse(json['cargaEstimada']?.toString() ?? '') ?? 0,
      fechaFinalizacion: DateTime.tryParse(
        json['fechaFinalizacion']?.toString() ?? '',
      ),
    );
  }
}
