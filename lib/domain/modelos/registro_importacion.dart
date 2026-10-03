enum EstadoImportacion { completada, fallida }

/// Logical audit contract. Storage and reliable inserted/updated counts remain
/// pending until the backend import/audit design is defined.
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
