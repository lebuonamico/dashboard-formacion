import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';

abstract class CrmTimeEntriesRepository {
  Future<List<CrmTimeEntry>> getTimeEntries({
    String? employeeId,
    String? courseId,
    DateTime? from,
    DateTime? until,
  });
  Future<void> replaceTimeEntries(List<CrmTimeEntry> timeEntries);
  Future<void> resetToMock();
}

extension CrmTimeEntriesUpsert on CrmTimeEntriesRepository {
  Future<UpsertResult> upsertTimeEntriesWithResult(
    List<CrmTimeEntry> items,
  ) async {
    if (items.isEmpty) return UpsertResult.empty;
    if (this is CountedUpsertRepository<CrmTimeEntry>) {
      return (this as CountedUpsertRepository<CrmTimeEntry>).upsertWithResult(
        items,
      );
    }
    await upsertTimeEntries(items);
    return UpsertResult(processedRecords: items.length);
  }

  Future<void> upsertTimeEntries(List<CrmTimeEntry> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<CrmTimeEntry>) {
      await (this as UpsertRepository<CrmTimeEntry>).upsert(items);
      return;
    }
    final merged = <String, CrmTimeEntry>{};
    for (final item in [...await getTimeEntries(), ...items]) {
      merged[item.id] = item;
    }
    await replaceTimeEntries(merged.values.toList());
  }
}
