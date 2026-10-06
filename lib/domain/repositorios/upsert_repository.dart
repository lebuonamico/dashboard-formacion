import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';

// Capability used by importers without coupling them to Supabase.
abstract interface class UpsertRepository<T> {
  Future<void> upsert(List<T> items);
}

abstract interface class CountedUpsertRepository<T>
    implements UpsertRepository<T> {
  Future<ResultadoUpsert> upsertConResultado(List<T> items);
}
