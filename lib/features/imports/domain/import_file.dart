import 'dart:typed_data';

enum ImportFileType { payroll, courseCatalog, timeEntries, certifications }

class ImportFile {
  final String name;
  final Uint8List bytes;

  const ImportFile({required this.name, required this.bytes});
}
