import 'dart:convert';
import 'dart:typed_data';

import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:excel/excel.dart';

ImportFile csvFile(String content, {String name = 'archivo.csv'}) =>
    ImportFile(name: name, bytes: Uint8List.fromList(utf8.encode(content)));

/// An xlsx workbook with one sheet per entry, in order. Cells may be
/// `String`, `int`, `double`, `bool`, `null` or an excel `CellValue`.
ImportFile xlsxFile(
  Map<String, List<List<Object?>>> sheets, {
  String name = 'archivo.xlsx',
}) => ImportFile(name: name, bytes: xlsxBytes(sheets));

Uint8List xlsxBytes(Map<String, List<List<Object?>>> sheets) {
  final workbook = Excel.createExcel();
  final defaultSheet = workbook.getDefaultSheet()!;
  for (final MapEntry(key: name, value: rows) in sheets.entries) {
    for (final row in rows) {
      workbook.appendRow(name, row.map(_cell).toList());
    }
  }
  if (!sheets.containsKey(defaultSheet)) {
    workbook.setDefaultSheet(sheets.keys.first);
    workbook.delete(defaultSheet);
  }
  return Uint8List.fromList(workbook.encode()!);
}

CellValue? _cell(Object? value) => switch (value) {
  null => null,
  final CellValue cell => cell,
  final String text => TextCellValue(text),
  final int number => IntCellValue(number),
  final double number => DoubleCellValue(number),
  final bool flag => BoolCellValue(flag),
  _ => TextCellValue(value.toString()),
};
