// Capability for movements that can be corrected by removing a whole month.
abstract interface class EliminacionPorMesRepository {
  /// Borra los registros cuya fecha cae en [mes]/[anio] y devuelve cuántos borró.
  Future<int> eliminarMes({required int anio, required int mes});
}

class MesConRegistros {
  final int anio;
  final int mes;
  final int cantidad;

  const MesConRegistros({
    required this.anio,
    required this.mes,
    required this.cantidad,
  });

  bool contiene(DateTime fecha) => fecha.year == anio && fecha.month == mes;
}

/// Meses con al menos un registro, del más reciente al más antiguo.
List<MesConRegistros> mesesConRegistros(Iterable<DateTime?> fechas) {
  final cantidades = <(int, int), int>{};
  for (final fecha in fechas) {
    if (fecha == null) continue;
    cantidades.update(
      (fecha.year, fecha.month),
      (cantidad) => cantidad + 1,
      ifAbsent: () => 1,
    );
  }
  final meses = [
    for (final entry in cantidades.entries)
      MesConRegistros(
        anio: entry.key.$1,
        mes: entry.key.$2,
        cantidad: entry.value,
      ),
  ];
  meses.sort(
    (a, b) => a.anio != b.anio ? b.anio.compareTo(a.anio) : b.mes - a.mes,
  );
  return meses;
}
