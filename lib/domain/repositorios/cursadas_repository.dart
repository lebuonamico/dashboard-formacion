import 'package:app_finnegans/domain/modelos/cursada.dart';

abstract class CursadasRepository {
  Future<List<Cursada>> getCursadas();
  Future<void> replaceCursadas(List<Cursada> cursadas);
  Future<void> resetToMock();
}
