import 'dart:typed_data';

abstract interface class PrintRepository {
  /// Opens the browser's or the system's print dialog, which can also save
  /// it as a PDF.
  Future<void> printPdf(Uint8List bytes, {required String fileName});

  /// Saves the PDF as [fileName]. On the web it is a download, without
  /// opening another tab.
  Future<void> downloadPdf(Uint8List bytes, {required String fileName});
}
