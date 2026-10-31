import 'dart:convert';
import 'dart:typed_data';

import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

typedef SheetRows = List<List<String>>;

/// Every cell as text, by sheet name. A CSV is a single sheet named `CSV`.
class SpreadsheetReader {
  const SpreadsheetReader();

  Map<String, SheetRows> read(ImportFile file) =>
      file.name.toLowerCase().endsWith('.xlsx')
      ? readExcel(file.bytes)
      : {'CSV': readCsv(file.bytes)};

  Map<String, SheetRows> readExcel(Uint8List bytes) =>
      Excel.decodeBytes(bytes).tables.map(
        (name, sheet) => MapEntry(
          name,
          sheet.rows
              .map(
                (row) =>
                    row.map((cell) => cell?.value?.toString() ?? '').toList(),
              )
              .toList(),
        ),
      );

  SheetRows readCsv(Uint8List bytes) {
    final text = utf8.decode(bytes);
    final content = (text.startsWith('\ufeff') ? text.substring(1) : text)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    // CsvToListConverter splits rows only on its `eol` ('\r\n' by default):
    // with any other line ending the whole file would be a single row.
    return const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(content)
        .map((row) => row.map((cell) => cell.toString()).toList())
        .toList();
  }
}
