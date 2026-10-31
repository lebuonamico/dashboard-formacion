import 'dart:typed_data';

abstract interface class PrintRepository {
  /// Opens the browser's or the system's print dialog, which can also save
  /// it as a PDF.
  Future<void> printPdf(Uint8List bytes, {required String fileName});
}
