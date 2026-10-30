import 'dart:typed_data';

import 'package:app_finnegans/domain/repositorios/impresion_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PrintingPrintRepository implements PrintRepository {
  const PrintingPrintRepository();

  @override
  Future<void> printPdf(Uint8List bytes, {required String fileName}) async {
    await Printing.layoutPdf(
      name: fileName,
      format: PdfPageFormat.a4,
      onLayout: (_) async => bytes,
    );
  }
}
