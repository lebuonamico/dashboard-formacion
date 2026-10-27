import 'dart:typed_data';

abstract interface class ImpresionRepository {
  /// Abre el diálogo de impresión del navegador o del sistema, desde donde
  /// también se puede guardar como PDF.
  Future<void> imprimirPdf(Uint8List bytes, {required String nombreArchivo});
}
