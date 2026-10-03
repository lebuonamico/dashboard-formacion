// Capability used by importers without coupling them to Supabase.
abstract interface class UpsertRepository<T> {
  Future<void> upsert(List<T> items);
}
