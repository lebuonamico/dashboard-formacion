import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/imports/data/spreadsheet_reader.dart';

List<String> normalizedHeaders(List<String> row) =>
    row.map(normalizeKey).toList();

/// Real spreadsheets carry titles above the header row, so it is searched
/// among the first [maxRows] rows. Returns -1 when none matches.
int findHeaderRow(
  SheetRows rows,
  bool Function(List<String> headers) matches, {
  int maxRows = 15,
}) => rows.take(maxRows).map(normalizedHeaders).toList().indexWhere(matches);

/// The column of the first alias present in [headers], or -1.
int columnFor(List<String> headers, List<String> aliases) => aliases
    .map(headers.indexOf)
    .firstWhere((index) => index != -1, orElse: () => -1);

bool hasColumn(List<String> headers, List<String> aliases) =>
    columnFor(headers, aliases) != -1;

bool rowHasData(List<String> row) => row.any((cell) => cell.trim().isNotEmpty);
