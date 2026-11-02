import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

abstract interface class CrmTimeEntriesRepository {
  Future<List<CrmTimeEntry>> getTimeEntries();

  /// Entries absent from [timeEntries] are kept.
  Future<UpsertResult> upsert(List<CrmTimeEntry> timeEntries);
}
