import 'package:supabase_flutter/supabase_flutter.dart';

enum DataErrorKind {
  /// A [FormatException]: its message is meant for the user.
  invalidData,

  /// Missing column or table: the database and the app do not match.
  schemaMismatch,
  forbidden,
  sessionExpired,
  network,
  unknown,
}

/// Why a read or write against the data source failed, without the caller
/// knowing about Supabase.
DataErrorKind classifyDataError(Object error) {
  if (error is FormatException) return DataErrorKind.invalidData;
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (const {'42703', '42P01', 'PGRST204', 'PGRST205'}.contains(code)) {
      return DataErrorKind.schemaMismatch;
    }
    if (code == '42501' || code == 'PGRST301') return DataErrorKind.forbidden;
  }
  if (error is AuthException) return DataErrorKind.sessionExpired;
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed to fetch') ||
      text.contains('TimeoutException')) {
    return DataErrorKind.network;
  }
  return DataErrorKind.unknown;
}
