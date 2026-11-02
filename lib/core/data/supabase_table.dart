import 'dart:convert';

import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads and UPSERTs one PostgREST table through its [SupabaseTableMapping].
class SupabaseTable {
  final SupabaseClient client;
  final SupabaseTableMapping mapping;

  SupabaseTable(this.client, this.mapping);

  Future<List<Map<String, dynamic>>> read() async {
    PostgrestTransformBuilder<PostgrestList> page(int from, int to) {
      final query = client
          .from(mapping.table)
          .select(mapping.columns.values.join(','));
      final ordered = mapping.conflictFields
          .skip(1)
          .fold(
            query.order(mapping.column(mapping.conflictFields.first)),
            (ordered, field) => ordered.order(mapping.column(field)),
          );
      return ordered.range(from, to);
    }

    // PostgREST caps responses: paginate instead of silently truncating. The
    // first page brings the total, so the rest is requested at once, stepping
    // by what the server actually returned.
    const pageSize = 1000;
    final first = await page(0, pageSize - 1).count(CountOption.exact);
    final step = first.data.length;
    final rest = step > 0 && step < first.count
        ? await Future.wait([
            for (var offset = step; offset < first.count; offset += step)
              page(offset, offset + step - 1),
          ])
        : const <PostgrestList>[];
    return [
      ...first.data,
      ...rest.expand((rows) => rows),
    ].map(mapping.decode).toList();
  }

  String _key(Map<String, dynamic> row) => jsonEncode([
    for (final field in mapping.conflictFields)
      row[mapping.column(field)]?.toString(),
  ]);

  Future<Set<String>> _existingKeys(List<Map<String, dynamic>> rows) async {
    final columns = mapping.conflictFields.map(mapping.column).toList();
    final selectedKeys = rows.map(_key).toSet();
    final existingKeys = <String>{};
    const batchSize = 150;
    const pageSize = 100;
    for (var start = 0; start < rows.length; start += batchSize) {
      final batch = rows.sublist(
        start,
        start + batchSize < rows.length ? start + batchSize : rows.length,
      );
      for (var offset = 0; ; offset += pageSize) {
        var query = client.from(mapping.table).select(columns.join(','));
        if (columns.length == 1) {
          query = query.inFilter(
            columns.single,
            batch.map((row) => row[columns.single]).toList(),
          );
        } else {
          // Quote strings as PostgREST literals, including embedded quotes,
          // backslashes and punctuation; each AND identifies one exact pair.
          query = query.or(
            batch
                .map(
                  (row) =>
                      'and(${columns.map((column) => '$column.eq.${jsonEncode(row[column])}').join(',')})',
                )
                .join(','),
          );
        }
        final ordered = columns
            .skip(1)
            .fold(
              query.order(columns.first),
              (ordered, column) => ordered.order(column),
            );
        final existing = await ordered.range(offset, offset + pageSize - 1);
        existingKeys.addAll(existing.map(_key).where(selectedKeys.contains));
        if (existing.length < pageSize) break;
      }
    }
    return existingKeys;
  }

  /// [records] use the mapping's logical keys.
  Future<({int inserted, int updated})> upsert(
    List<Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return (inserted: 0, updated: 0);
    final encoded = records.map(mapping.encode).toList();
    final missingKey = mapping.conflictFields
        .where(
          (field) => encoded.any((row) => row[mapping.column(field)] == null),
        )
        .firstOrNull;
    if (missingKey != null) {
      throw FormatException('Falta una clave de UPSERT: $missingKey.');
    }
    // PostgreSQL cannot UPSERT the same conflict key twice in one statement.
    final rows = {for (final row in encoded) _key(row): row}.values.toList();
    final existingKeys = await _existingKeys(rows);
    await client
        .from(mapping.table)
        .upsert(rows, onConflict: mapping.onConflict);
    return (
      inserted: rows.length - existingKeys.length,
      updated: existingKeys.length,
    );
  }
}
