enum EstadoImportacion { completada, fallida }

/// Audit result; legacy repositories may leave persistence counts unknown.
class RegistroImportacion {
  final String tipoArchivo;
  final String nombreArchivo;
  final DateTime fechaHora;
  final EstadoImportacion estado;
  final int registrosProcesados;
  final int? insertados;
  final int? actualizados;
  final List<String> errores;

  const RegistroImportacion({
    required this.tipoArchivo,
    required this.nombreArchivo,
    required this.fechaHora,
    required this.estado,
    required this.registrosProcesados,
    this.insertados,
    this.actualizados,
    this.errores = const [],
  });
}
