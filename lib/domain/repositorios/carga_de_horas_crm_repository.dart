import 'package:app_finnegans/domain/repositorios/upsert_repository.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';

abstract class CargaDeHorasCRMRepository {
  Future<List<CargaDeHorasCRM>> getCargasDeHoras({
    String? empleadoLegajo,
    String? cursoId,
    DateTime? desde,
    DateTime? hasta,
  });
  Future<void> replaceCargasDeHoras(List<CargaDeHorasCRM> cargas);
  Future<void> resetToMock();
}

extension CargaDeHorasCRMUpsert on CargaDeHorasCRMRepository {
  Future<void> upsertCargasDeHoras(List<CargaDeHorasCRM> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<CargaDeHorasCRM>) {
      await (this as UpsertRepository<CargaDeHorasCRM>).upsert(items);
      return;
    }
    final merged = <String, CargaDeHorasCRM>{};
    for (final item in [...await getCargasDeHoras(), ...items]) {
      merged[item.id] = item;
    }
    await replaceCargasDeHoras(merged.values.toList());
  }
}
