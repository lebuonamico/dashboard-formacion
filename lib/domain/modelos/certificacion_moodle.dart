class CertificacionMoodle {
  final String legajo;
  final String cursoNombre;
  final bool finalizoCurso;
  final DateTime? fechaFinalizacion;

  const CertificacionMoodle({
    required this.legajo,
    required this.cursoNombre,
    required this.finalizoCurso,
    this.fechaFinalizacion,
  });

  Map<String, dynamic> toJson() => {
    'legajo': legajo,
    'cursoNombre': cursoNombre,
    'finalizoCurso': finalizoCurso,
    'fechaFinalizacion': fechaFinalizacion?.toIso8601String(),
  };

  factory CertificacionMoodle.fromJson(Map<String, dynamic> json) {
    final finalizo = json['finalizoCurso'];
    return CertificacionMoodle(
      legajo: json['legajo']?.toString() ?? '',
      cursoNombre: json['cursoNombre']?.toString() ?? '',
      finalizoCurso: finalizo == true || finalizo?.toString() == 'true',
      fechaFinalizacion: DateTime.tryParse(
        json['fechaFinalizacion']?.toString() ?? '',
      ),
    );
  }
}
