class CertificacionMoodle {
  final String legajo;
  final String cursoNombre;
  final bool finalizoCurso;
  final double cargaEstimada;

  const CertificacionMoodle({
    required this.legajo,
    required this.cursoNombre,
    required this.finalizoCurso,
    required this.cargaEstimada,
  });

  Map<String, dynamic> toJson() => {
    'legajo': legajo,
    'cursoNombre': cursoNombre,
    'finalizoCurso': finalizoCurso,
    'cargaEstimada': cargaEstimada,
  };

  factory CertificacionMoodle.fromJson(Map<String, dynamic> json) {
    final finalizo = json['finalizoCurso'];
    return CertificacionMoodle(
      legajo: json['legajo']?.toString() ?? '',
      cursoNombre: json['cursoNombre']?.toString() ?? '',
      finalizoCurso: finalizo == true || finalizo?.toString() == 'true',
      cargaEstimada:
          double.tryParse(json['cargaEstimada']?.toString() ?? '') ?? 0,
    );
  }
}
