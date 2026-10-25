import 'dart:typed_data';

import 'package:app_finnegans/domain/repositorios/impresion_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PrintingImpresionRepository implements ImpresionRepository {
  const PrintingImpresionRepository();

  @override
  Future<void> imprimirPdf(
    Uint8List bytes, {
    required String nombreArchivo,
  }) async {
    await Printing.layoutPdf(
      name: nombreArchivo,
      format: PdfPageFormat.a4,
      onLayout: (_) async => bytes,
    );
  }
}
