import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/time_entries/data/crm_time_entries_seed.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

class InMemoryCrmTimeEntriesRepository implements CrmTimeEntriesRepository {
  final Map<String, CrmTimeEntry> _timeEntries;

  InMemoryCrmTimeEntriesRepository([List<CrmTimeEntry>? timeEntries])
    : _timeEntries = {
        for (final entry in timeEntries ?? crmTimeEntriesSeed) entry.id: entry,
      };

  @override
  Future<List<CrmTimeEntry>> getTimeEntries() async => [..._timeEntries.values];

  @override
  Future<UpsertResult> upsert(List<CrmTimeEntry> timeEntries) async {
    final unique = {for (final entry in timeEntries) entry.id: entry};
    final inserted = unique.keys
        .where((id) => !_timeEntries.containsKey(id))
        .length;
    _timeEntries.addAll(unique);
    return UpsertResult(
      processedRecords: timeEntries.length,
      inserted: inserted,
      updated: unique.length - inserted,
    );
  }
}
