import 'dart:typed_data';

abstract interface class PrintRepository {
  /// Abre el diálogo de impresión del navegador o del sistema, desde donde
  /// también se puede guardar como PDF.
  Future<void> printPdf(Uint8List bytes, {required String fileName});
}
