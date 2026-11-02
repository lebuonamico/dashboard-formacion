import 'dart:convert';

String cellAt(List<String> row, int index) =>
    index >= 0 && index < row.length ? row[index].trim() : '';

String sheetLocation(String sheet, int rowIndex) =>
    'hoja "$sheet", fila ${rowIndex + 1}';

void requireUniqueHeaders(List<String> headers, String sheet) {
  final seen = <String>{};
  final duplicate = headers
      .where((header) => header.isNotEmpty)
      .firstWhere((header) => !seen.add(header), orElse: () => '');
  if (duplicate.isNotEmpty) {
    throw FormatException(
      'Encabezado duplicado "$duplicate" en la hoja "$sheet".',
    );
  }
}

void requireHeaderForEveryCell(
  List<String> row,
  List<String> headers,
  String location,
) {
  final orphan = row.indexed.any(
    (cell) =>
        cell.$2.trim().isNotEmpty &&
        (cell.$1 >= headers.length || headers[cell.$1].isEmpty),
  );
  if (orphan) {
    throw FormatException('Hay datos sin encabezado de columna en $location.');
  }
}

/// A master file may repeat a row, but not the same key with other data.
void requireConsistentRecord({
  required Map<String, dynamic>? previous,
  required Map<String, dynamic> current,
  required String key,
  required String field,
  required String location,
}) {
  if (previous != null && jsonEncode(previous) != jsonEncode(current)) {
    throw FormatException(
      'El $field "$key" tiene datos contradictorios en $location.',
    );
  }
}
