/// Counts for a successfully persisted import batch.
/// Null counts mean the repository cannot distinguish inserts from updates.
class ResultadoUpsert {
  final int registrosProcesados;
  final int? insertados;
  final int? actualizados;

  const ResultadoUpsert({
    required this.registrosProcesados,
    this.insertados,
    this.actualizados,
  });

  static const empty = ResultadoUpsert(
    registrosProcesados: 0,
    insertados: 0,
    actualizados: 0,
  );

  ResultadoUpsert operator +(ResultadoUpsert other) => ResultadoUpsert(
    registrosProcesados: registrosProcesados + other.registrosProcesados,
    insertados: insertados == null || other.insertados == null
        ? null
        : insertados! + other.insertados!,
    actualizados: actualizados == null || other.actualizados == null
        ? null
        : actualizados! + other.actualizados!,
  );
}
