import 'dart:math';

import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorios que leen y guardan en Supabase, contra el esquema de
/// supabase/finnegans_supabase.sql.
///
/// CÓMO ACTUALIZA CADA IMPORTACIÓN
///
/// Los Excel de nómina y de cursos son fotos completas del estado actual, así
/// que `replaceEmpleados` y `replaceCursos` hacen:
///   1. upsert de todo lo que vino en el archivo, con activo = true;
///   2. baja lógica (activo = false) de lo que ya estaba en la base y NO vino en
///      el archivo.
/// Nunca se borra una fila: un empleado que se fue queda con activo = false, y
/// si vuelve a aparecer en un Excel posterior se reactiva solo. Las lecturas
/// devuelven únicamente los activos.
///
/// Los Excel de horas y de finalizaciones son hechos acumulativos, no fotos: se
/// hace upsert y no se da de baja nada (una transacción del CRM que no viene en
/// el archivo de este trimestre sigue siendo válida).
///
/// Las filas cuyo legajo no está en la nómina o cuyo curso no está en el
/// catálogo se descartan y se cuentan en `importaciones.registros_omitidos`, en
/// vez de hacer fallar el archivo entero por la clave foránea.

SupabaseClient get _db => Supabase.instance.client;

/// Cuántas filas se mandan por pedido al guardar.
const _filasPorLote = 500;

/// Supabase devuelve como máximo 1000 filas por consulta.
const _filasPorPagina = 1000;

/// Tipos de importación que audita la tabla `importaciones`.
class _TipoImportacion {
  static const nomina = 'NOMINA';
  static const cursos = 'CURSOS_LMS';
  static const horas = 'HORAS_CAPACITACION';
  static const estado = 'ESTADO_FINALIZACION';
}

class SupabaseEmpleadosRepository implements EmpleadosRepository {
  @override
  Future<List<Empleado>> getEmpleados() => _conMensajes(() async {
    final filas = await _leerTodo(
      'empleados',
      columnas:
          'legajo, correo, nombre, apellido, seniority, sector, equipo_general, gerente',
      ordenarPor: const ['legajo'],
      soloActivos: true,
    );
    return filas
        .map(
          (fila) => Empleado.fromJson({
            'legajo': '${fila['legajo']}',
            'nombre': fila['nombre'],
            'apellido': fila['apellido'],
            'seniority': fila['seniority'],
            'area': fila['sector'],
            'mail': fila['correo'],
            'equipo': fila['equipo_general'],
            'gerente': fila['gerente'],
          }),
        )
        .toList();
  });

  /// Foto completa de la nómina: lo que no viene en el archivo se da de baja.
  @override
  Future<void> replaceEmpleados(List<Empleado> empleados) => _conMensajes(() async {
    var omitidos = 0;
    final filas = <Map<String, dynamic>>[];
    for (final empleado in empleados) {
      final legajo = _aEntero(empleado.legajo);
      final correo = empleado.mail.trim();
      // El legajo es la clave y el correo es único y obligatorio: sin ellos la
      // fila no entra.
      if (legajo == null || correo.isEmpty) {
        omitidos++;
        continue;
      }
      filas.add({
        'legajo': legajo,
        'correo': correo,
        'nombre': empleado.nombre.trim(),
        'apellido': empleado.apellido.trim(),
        'seniority': empleado.seniority.name,
        'sector': empleado.area.trim(),
        'equipo_general': empleado.equipo.trim(),
        'gerente': empleado.gerente.trim().isEmpty ? null : empleado.gerente.trim(),
        'activo': true,
      });
    }

    await _sincronizarMaestro(
      tabla: 'empleados',
      tipoImportacion: _TipoImportacion.nomina,
      columnaClave: 'legajo',
      filas: _sinRepetidos(filas, (fila) => '${fila['legajo']}'),
      omitidos: omitidos,
    );
  });

  /// En Supabase no se borran datos desde la app.
  @override
  Future<void> resetToMock() async {}
}

class SupabaseCursosRepository implements CursosRepository {
  @override
  Future<List<Curso>> getCursos() => _conMensajes(() async {
    final filas = await _leerTodo(
      'cursos',
      columnas:
          'id_curso, nombre, tipo, carga_horaria, area_curso, instructor_legajo',
      ordenarPor: const ['nombre'],
      soloActivos: true,
    );
    return filas
        .map(
          (fila) => Curso.fromJson({
            'id': '${fila['id_curso']}',
            'nombre': fila['nombre'],
            'tipo': fila['tipo'],
            'areaCurso': fila['area_curso'],
            'instructorLegajo': fila['instructor_legajo'],
            'cargaHorariaHs': fila['carga_horaria'],
          }),
        )
        .toList();
  });

  /// Foto completa del catálogo: lo que no viene en el archivo se da de baja.
  ///
  /// La clave es el nombre, porque es por nombre que el CRM y Moodle se
  /// refieren a un curso. El `id_curso` lo genera la base; si el curso vino de
  /// la API de Moodle, su id numérico se guarda en `id_moodle`.
  @override
  Future<void> replaceCursos(List<Curso> cursos) => _conMensajes(() async {
    var omitidos = 0;
    final filas = <Map<String, dynamic>>[];
    for (final curso in cursos) {
      final nombre = curso.nombre.trim();
      if (nombre.isEmpty) {
        omitidos++;
        continue;
      }
      filas.add({
        'nombre': nombre,
        'id_moodle': _aEntero(curso.id),
        'tipo': curso.tipo.name,
        'carga_horaria': max(curso.cargaHorariaHs, 0.0),
        'area_curso': curso.areaCurso.trim(),
        'instructor_legajo': curso.instructorLegajo.trim(),
        'activo': true,
      });
    }

    await _sincronizarMaestro(
      tabla: 'cursos',
      tipoImportacion: _TipoImportacion.cursos,
      columnaClave: 'nombre',
      filas: _sinRepetidos(filas, (fila) => '${fila['nombre']}'),
      omitidos: omitidos,
    );
  });

  /// En Supabase no se borran datos desde la app.
  @override
  Future<void> resetToMock() async {}
}

class SupabaseCargaDeHorasCRMRepository implements CargaDeHorasCRMRepository {
  @override
  Future<List<CargaDeHorasCRM>> getCargasDeHoras() => _conMensajes(() async {
    final filas = await _leerTodo(
      'horas_capacitacion',
      columnas:
          'transaccion_id, legajo, fecha, horas_totales, tipo, cursos!inner(nombre)',
      ordenarPor: const ['transaccion_id'],
    );
    return filas
        .map(
          (fila) => CargaDeHorasCRM.fromJson({
            'id': '${fila['transaccion_id']}',
            'cursoNombre': _embebido(fila, 'cursos')?['nombre'],
            'empleadoLegajo': '${fila['legajo']}',
            'fecha': fila['fecha'],
            'horasTotales': fila['horas_totales'],
            'tipo': fila['tipo'],
          }),
        )
        .toList();
  });

  /// Hechos acumulativos: se hace upsert por id de transacción y no se da de
  /// baja nada. Una transacción corregida en un Excel posterior se actualiza.
  @override
  Future<void> replaceCargasDeHoras(List<CargaDeHorasCRM> cargas) =>
      _conMensajes(() async {
        final cursos = await _idsDeCursosPorNombre();
        final legajos = await _legajosEnNomina();
        var omitidos = 0;
        final filas = <Map<String, dynamic>>[];
        for (final carga in cargas) {
          final id = _aEntero(carga.id);
          final legajo = _aEntero(carga.empleadoLegajo);
          final cursoId = cursos[carga.cursoNombre.trim()];
          // Claves foráneas: si el legajo o el curso no existen, la base
          // rechazaría el lote completo. Se descarta la fila y se cuenta.
          if (id == null ||
              legajo == null ||
              cursoId == null ||
              !legajos.contains(legajo) ||
              carga.horasTotales < 0) {
            omitidos++;
            continue;
          }
          filas.add({
            'transaccion_id': id,
            'legajo': legajo,
            'curso_id': cursoId,
            'fecha': _soloFecha(carga.fecha),
            'horas_totales': carga.horasTotales,
            'tipo': carga.tipo.name,
          });
        }

        await _sincronizarAcumulativo(
          tabla: 'horas_capacitacion',
          tipoImportacion: _TipoImportacion.horas,
          onConflict: 'transaccion_id',
          filas: _sinRepetidos(filas, (fila) => '${fila['transaccion_id']}'),
          omitidos: omitidos,
        );
      });

  /// En Supabase no se borran datos desde la app.
  @override
  Future<void> resetToMock() async {}
}

class SupabaseCertificacionesMoodleRepository
    implements CertificacionesMoodleRepository {
  @override
  Future<List<CertificacionMoodle>> getCertificaciones() =>
      _conMensajes(() async {
        final filas = await _leerTodo(
          'estado_cursos',
          // La carga estimada no se guarda acá: sale del curso, para no tener el
          // mismo número en dos tablas.
          columnas:
              'legajo, curso_id, finalizo, fecha_finalizacion, cursos!inner(nombre, carga_horaria)',
          ordenarPor: const ['legajo', 'curso_id'],
        );
        return filas.map((fila) {
          final curso = _embebido(fila, 'cursos');
          return CertificacionMoodle.fromJson({
            'legajo': '${fila['legajo']}',
            'cursoNombre': curso?['nombre'],
            'finalizoCurso': fila['finalizo'],
            'cargaEstimada': curso?['carga_horaria'],
            'fechaFinalizacion': fila['fecha_finalizacion'],
          });
        }).toList();
      });

  /// Hechos acumulativos: upsert por legajo + curso. Un curso que ya figuraba
  /// como finalizado no vuelve a "no finalizado" (lo garantiza un trigger en la
  /// base).
  @override
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  ) => _conMensajes(() async {
    final cursos = await _idsDeCursosPorNombre();
    final legajos = await _legajosEnNomina();
    var omitidos = 0;
    final filas = <Map<String, dynamic>>[];
    for (final item in certificaciones) {
      final legajo = _aEntero(item.legajo);
      final cursoId = cursos[item.cursoNombre.trim()];
      // La base exige fecha cuando finalizó: sin ella la fila no entra.
      if (legajo == null ||
          cursoId == null ||
          !legajos.contains(legajo) ||
          (item.finalizoCurso && item.fechaFinalizacion == null)) {
        omitidos++;
        continue;
      }
      filas.add({
        'legajo': legajo,
        'curso_id': cursoId,
        'finalizo': item.finalizoCurso,
        'fecha_finalizacion': item.fechaFinalizacion == null
            ? null
            : _soloFecha(item.fechaFinalizacion!),
      });
    }

    await _sincronizarAcumulativo(
      tabla: 'estado_cursos',
      tipoImportacion: _TipoImportacion.estado,
      onConflict: 'legajo,curso_id',
      filas: _sinRepetidos(
        filas,
        (fila) => '${fila['legajo']}|${fila['curso_id']}',
      ),
      omitidos: omitidos,
    );
  });
}

// ---------------------------------------------------------------------------
// Sincronización
// ---------------------------------------------------------------------------

/// Tabla maestra (nómina, catálogo de cursos): el archivo es una foto completa.
/// Se da de alta o se actualiza lo que vino, y se da de baja lógica lo que no.
Future<void> _sincronizarMaestro({
  required String tabla,
  required String tipoImportacion,
  required String columnaClave,
  required List<Map<String, dynamic>> filas,
  required int omitidos,
}) async {
  final clavesEnBase = await _clavesExistentes(tabla, columnaClave);
  final clavesDelArchivo = filas.map((fila) => '${fila[columnaClave]}').toSet();
  final insertados = clavesDelArchivo.difference(clavesEnBase).length;
  final aDesactivar = clavesEnBase.difference(clavesDelArchivo).toList();

  try {
    await _guardar(tabla, filas, onConflict: columnaClave);
    await _bajaLogica(tabla, columnaClave, aDesactivar);
  } on Object catch (error) {
    await _registrarImportacion(
      tipo: tipoImportacion,
      procesados: filas.length + omitidos,
      insertados: 0,
      actualizados: 0,
      desactivados: 0,
      omitidos: omitidos,
      error: error.toString(),
    );
    rethrow;
  }

  await _registrarImportacion(
    tipo: tipoImportacion,
    procesados: filas.length + omitidos,
    insertados: insertados,
    actualizados: filas.length - insertados,
    desactivados: aDesactivar.length,
    omitidos: omitidos,
  );
}

/// Tabla de hechos (horas, finalizaciones): el archivo aporta novedades, no una
/// foto. Se da de alta o se actualiza, y no se da de baja nada.
Future<void> _sincronizarAcumulativo({
  required String tabla,
  required String tipoImportacion,
  required String onConflict,
  required List<Map<String, dynamic>> filas,
  required int omitidos,
}) async {
  final claves = onConflict.split(',');
  final clavesEnBase = await _clavesExistentes(tabla, onConflict);
  final clavesDelArchivo = filas
      .map((fila) => claves.map((clave) => '${fila[clave]}').join('|'))
      .toSet();
  final insertados = clavesDelArchivo.difference(clavesEnBase).length;

  try {
    await _guardar(tabla, filas, onConflict: onConflict);
  } on Object catch (error) {
    await _registrarImportacion(
      tipo: tipoImportacion,
      procesados: filas.length + omitidos,
      insertados: 0,
      actualizados: 0,
      desactivados: 0,
      omitidos: omitidos,
      error: error.toString(),
    );
    rethrow;
  }

  await _registrarImportacion(
    tipo: tipoImportacion,
    procesados: filas.length + omitidos,
    insertados: insertados,
    actualizados: filas.length - insertados,
    desactivados: 0,
    omitidos: omitidos,
  );
}

/// Marca como inactivo lo que ya no viene en el archivo. No borra: la fila sigue
/// ahí con activo = false y se reactiva si vuelve a aparecer.
Future<void> _bajaLogica(
  String tabla,
  String columnaClave,
  List<String> claves,
) async {
  if (claves.isEmpty) return;
  // De a lotes porque el filtro viaja en la URL del pedido.
  const porLote = 200;
  for (var inicio = 0; inicio < claves.length; inicio += porLote) {
    final lote = claves.sublist(inicio, min(inicio + porLote, claves.length));
    await _db
        .from(tabla)
        .update({'activo': false})
        .inFilter(columnaClave, _comoValoresDeColumna(tabla, columnaClave, lote));
  }
}

/// `legajo` es entero en la base: si se manda como texto el filtro no matchea.
List<Object> _comoValoresDeColumna(
  String tabla,
  String columna,
  List<String> claves,
) {
  if (columna == 'legajo') {
    return claves.map((clave) => int.parse(clave)).toList();
  }
  return claves;
}

/// Las claves que ya están en la tabla, como texto (`a|b` si son compuestas).
Future<Set<String>> _clavesExistentes(String tabla, String onConflict) async {
  final columnas = onConflict.split(',');
  final filas = await _leerTodo(
    tabla,
    columnas: onConflict,
    ordenarPor: columnas,
  );
  return filas
      .map((fila) => columnas.map((columna) => '${fila[columna]}').join('|'))
      .toSet();
}

Future<Map<String, int>> _idsDeCursosPorNombre() async {
  final filas = await _leerTodo(
    'cursos',
    columnas: 'id_curso, nombre',
    ordenarPor: const ['nombre'],
    soloActivos: true,
  );
  return {
    for (final fila in filas) '${fila['nombre']}': fila['id_curso'] as int,
  };
}

Future<Set<int>> _legajosEnNomina() async {
  final filas = await _leerTodo(
    'empleados',
    columnas: 'legajo',
    ordenarPor: const ['legajo'],
    soloActivos: true,
  );
  return {for (final fila in filas) fila['legajo'] as int};
}

Future<void> _registrarImportacion({
  required String tipo,
  required int procesados,
  required int insertados,
  required int actualizados,
  required int desactivados,
  required int omitidos,
  String? error,
}) async {
  // La auditoría no debe hacer fallar una importación que salió bien.
  try {
    await _db.from('importaciones').insert({
      'tipo': tipo,
      // TODO: pasar el nombre real del archivo desde la pantalla de
      // Configuración (hoy los repositorios no lo reciben).
      'nombre_archivo': 'importado desde la app',
      'estado': error == null ? 'EXITOSA' : 'ERROR',
      'registros_procesados': procesados,
      'registros_insertados': insertados,
      'registros_actualizados': actualizados,
      'registros_desactivados': desactivados,
      'registros_omitidos': omitidos,
      'mensaje_error': error,
    });
  } on Object {
    return;
  }
}

// ---------------------------------------------------------------------------
// Acceso a la base
// ---------------------------------------------------------------------------

/// Lee todas las filas de una tabla, de a páginas.
Future<List<Map<String, dynamic>>> _leerTodo(
  String tabla, {
  required String columnas,
  required List<String> ordenarPor,
  bool soloActivos = false,
}) async {
  final filas = <Map<String, dynamic>>[];
  var desde = 0;
  while (true) {
    var filtro = _db.from(tabla).select(columnas);
    if (soloActivos) filtro = filtro.eq('activo', true);
    PostgrestTransformBuilder<List<Map<String, dynamic>>> consulta = filtro
        .order(ordenarPor.first, ascending: true);
    for (final columna in ordenarPor.skip(1)) {
      consulta = consulta.order(columna, ascending: true);
    }
    final pagina = await consulta.range(desde, desde + _filasPorPagina - 1);
    filas.addAll(pagina);
    if (pagina.length < _filasPorPagina) return filas;
    desde += _filasPorPagina;
  }
}

/// Inserta o actualiza las filas, de a lotes.
///
/// Cada lote es un pedido aparte, así que no hay transacción que los abarque:
/// si falla el lote 3, los dos primeros ya quedaron guardados. Como todo son
/// upserts, volver a cargar el mismo archivo después de corregirlo es seguro.
Future<void> _guardar(
  String tabla,
  List<Map<String, dynamic>> filas, {
  required String onConflict,
}) async {
  for (var inicio = 0; inicio < filas.length; inicio += _filasPorLote) {
    final lote = filas.sublist(
      inicio,
      min(inicio + _filasPorLote, filas.length),
    );
    await _db.from(tabla).upsert(lote, onConflict: onConflict);
  }
}

/// Si el mismo registro viene dos veces en el archivo, queda el último.
/// (La base rechaza actualizar dos veces la misma fila en un mismo pedido.)
List<Map<String, dynamic>> _sinRepetidos(
  List<Map<String, dynamic>> filas,
  String Function(Map<String, dynamic> fila) clave,
) {
  final porClave = <String, Map<String, dynamic>>{};
  for (final fila in filas) {
    porClave[clave(fila)] = fila;
  }
  return porClave.values.toList();
}

/// Una relación embebida (`cursos!inner(...)`) llega como mapa cuando es a-uno,
/// pero como lista de un elemento según cómo la resuelva PostgREST.
Map<String, dynamic>? _embebido(Map<String, dynamic> fila, String relacion) {
  final valor = fila[relacion];
  if (valor is Map<String, dynamic>) return valor;
  if (valor is List && valor.isNotEmpty && valor.first is Map) {
    return (valor.first as Map).cast<String, dynamic>();
  }
  return null;
}

// ---------------------------------------------------------------------------
// Conversiones
// ---------------------------------------------------------------------------

/// Los Excel traen los enteros como "5.0" o "2174334.0", así que no alcanza con
/// int.tryParse. Devuelve null si no es un número.
int? _aEntero(String valor) {
  final limpio = valor.trim();
  if (limpio.isEmpty) return null;
  return int.tryParse(limpio) ?? double.tryParse(limpio)?.toInt();
}

String _soloFecha(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Errores
// ---------------------------------------------------------------------------

/// Convierte los errores de la base en mensajes que la pantalla de
/// Configuración ya sabe mostrar.
Future<T> _conMensajes<T>(Future<T> Function() accion) async {
  try {
    return await accion();
  } on PostgrestException catch (error) {
    throw FormatException(_mensajeDeError(error));
  } on Object catch (error) {
    // Sin internet, DNS caído o proyecto de Supabase pausado: el cliente tira
    // SocketException o ClientException según la plataforma. Cualquier otro
    // error (un bug nuestro) se deja pasar tal cual para poder verlo.
    if (!_esErrorDeRed(error)) rethrow;
    throw const FormatException(
      'No hay conexión con la base de datos. Revisá tu internet y volvé a intentar.',
    );
  }
}

/// No usamos `dart:io` para no romper la compilación en web, así que miramos el
/// tipo del error por nombre.
bool _esErrorDeRed(Object error) {
  final tipo = error.runtimeType.toString();
  return tipo.contains('SocketException') ||
      tipo.contains('ClientException') ||
      tipo.contains('HandshakeException') ||
      tipo.contains('TimeoutException');
}

String _mensajeDeError(PostgrestException error) {
  final detalle = '${error.message} ${error.details ?? ''}';
  if (error.code == '23503') {
    if (detalle.contains('legajo')) {
      return 'Hay legajos que no están en la nómina. Cargá primero la nómina actualizada.';
    }
    if (detalle.contains('curso')) {
      return 'Hay cursos que no están en el catálogo. Cargá primero los cursos.';
    }
  }
  if (error.code == '23505' && detalle.contains('correo')) {
    return 'Hay dos empleados con el mismo correo en el archivo. Revisá la nómina.';
  }
  if (error.code == '23514') {
    if (detalle.contains('seniority')) {
      return 'Hay un seniority que no se pudo interpretar. Revisá la columna Señority del Excel.';
    }
    if (detalle.contains('tipo')) {
      return 'Hay un tipo de curso que no se pudo interpretar. Revisá la columna TipoCurso del Excel.';
    }
    if (detalle.contains('nombre')) {
      return 'Hay nombres de curso con espacios al principio o al final. Tienen que guardarse recortados.';
    }
    return 'Hay datos que la base rechazó por formato: ${error.message}';
  }
  if (error.code == '42P01' || error.code == 'PGRST205') {
    return 'Falta crear las tablas en Supabase. Corré el script supabase/finnegans_supabase.sql.';
  }
  return 'No se pudo guardar en la base de datos: ${error.message}';
}
