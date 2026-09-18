import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';

abstract class CargaDeHorasCRMRepository {
  Future<List<CargaDeHorasCRM>> getCargasDeHoras();
  Future<void> replaceCargasDeHoras(List<CargaDeHorasCRM> cargas);
  Future<void> resetToMock();
}
