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
}