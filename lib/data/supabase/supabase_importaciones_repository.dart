import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/domain/modelos/registro_importacion.dart';
import 'package:app_finnegans/domain/repositorios/importaciones_repository.dart';

class SupabaseImportacionesRepository implements ImportacionesRepository {
  final SupabaseClient _client;

  SupabaseImportacionesRepository(this._client);

  @override
  Future<void> registrar(RegistroImportacion registro) async {
    await _client.schema('public').from('importaciones').insert({
      'tipo_archivo': registro.tipoArchivo,
      'nombre_archivo': registro.nombreArchivo,
      'fecha_hora': registro.fechaHora.toIso8601String(),
      'estado': registro.estado.name,
      'registros_procesados': registro.registrosProcesados,
      'insertados': registro.insertados,
      'actualizados': registro.actualizados,
      'errores': registro.errores,
    });
  }
}
