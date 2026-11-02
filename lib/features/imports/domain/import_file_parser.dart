import 'package:app_finnegans/features/imports/domain/import_file.dart';

/// Reads an imported file into domain objects, or throws a
/// [FormatException] that explains why the whole file is rejected.
abstract interface class ImportFileParser<T> {
  T parse(ImportFile file);
}
