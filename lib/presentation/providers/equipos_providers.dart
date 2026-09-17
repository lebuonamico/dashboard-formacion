import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
//import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

// Leandro: Archivo compartido: también contiene modelos y providers de Áreas y del detalle.
// Leandro: El dashboard nuevo usa EquipoGlobalViewModel, equiposGlobalProvider
// Leandro: y equiposGlobalFiltradosProvider. Las otras pantallas conservan sus dependencias.

class ResumenEquipoViewModel {
  final String nombreArea;
  final int cantidadIntegrantes;
  final int integrantesCumplen;
  final double horasTotalesRealizadas;
  final double horasTotalesRequeridas;
  final double porcentajeCumplimiento;
  final EstadoSemaforo semaforo;
  final List<String> equiposGenerales;

  ResumenEquipoViewModel({
    required this.nombreArea,
    required this.cantidadIntegrantes,
    required this.integrantesCumplen,
    required this.horasTotalesRealizadas,
    required this.horasTotalesRequeridas,
    required this.porcentajeCumplimiento,
    required this.semaforo,
    required this.equiposGenerales,
  });
}

class DetalleEquipoViewModel {
  final String nombreArea;
  final ResumenEquipoViewModel resumen;
  final List<CumplimientoEmpleado> miembros;
  final Map<String, List<CumplimientoEmpleado>> miembrosPorEquipo;

  DetalleEquipoViewModel({
    required this.nombreArea,
    required this.resumen,
    required this.miembros,
    required this.miembrosPorEquipo,
  });
}

class DetalleEquipoGeneralViewModel {
  final String nombreArea;
  final String nombreEquipo;
  final List<CumplimientoEmpleado> miembros;

  DetalleEquipoGeneralViewModel({
    required this.nombreArea,
    required this.nombreEquipo,
    required this.miembros,
  });
}

/// Leandro: Datos preparados para representar un equipo en el dashboard global.
/// Leandro: El provider los calcula y EquipoCard los muestra; esta clase no dibuja widgets.
class EquipoGlobalViewModel {
  final String id;
  final String nombre;
  final String area;
  final String lider;
  final int cantidadIntegrantes;
  final int integrantesEnObjetivo;
  final double horasRealizadas;
  final double horasObjetivo;
  final double promedioPorColaborador;
  final double porcentajeCumplimiento;
  final EstadoSemaforo semaforo;

  EquipoGlobalViewModel({
    required this.id,
    required this.nombre,
    required this.area,
    required this.lider,
    required this.cantidadIntegrantes,
    required this.integrantesEnObjetivo,
    required this.horasRealizadas,
    required this.horasObjetivo,
    required this.promedioPorColaborador,
    required this.porcentajeCumplimiento,
    required this.semaforo,
  });
}

// Leandro: Estado de los controles: StateProvider conserva el valor actual en Riverpod.
// Leandro: Atención: busquedaEquipoProvider también lo usa Áreas; hoy comparten ese texto.
final busquedaEquipoProvider = StateProvider<String>((ref) => '');
// Leandro: El ? permite null: en estos filtros significa "todas las áreas / estados".
final filtroAreaEquipoProvider = StateProvider<String?>((ref) => null);
final filtroEstadoEquipoProvider = StateProvider<EstadoSemaforo?>((ref) => null);
/// Leandro: Prepara TODOS los equipos a partir del cumplimiento de cada persona.
/// Leandro: FutureProvider permite esperar datos y expone carga, error o resultado.
/// Leandro: No depende de los filtros: cambiar una búsqueda conserva esta lista completa.
final equiposGlobalProvider = FutureProvider<List<EquipoGlobalViewModel>>((
  ref,
) async {
  // Leandro: cumplimientoGlobalProvider reúne empleados, cursos y cursadas y usa el
  // Leandro: servicio de cumplimiento. await espera su resultado sin bloquear la interfaz.
  // Leandro: watch también declara que este provider depende de esos datos.
  final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);

  // Leandro: Map funciona como un diccionario: cada clave identifica área + equipo
  // Leandro: y su valor es la lista de personas con sus resultados de cumplimiento.
  final agrupadoPorEquipo = <String, List<CumplimientoEmpleado>>{};

  // Leandro: Primer recorrido: reunimos las personas que pertenecen al mismo equipo.
  for (final cumplimiento in cumplimientos) {
    final empleado = cumplimiento.empleado;
    // Leandro: trim quita espacios en los extremos. Los nombres vacíos se agrupan
    // Leandro: bajo "Sin equipo asignado" dentro del área correspondiente.
    final nombreEquipo = empleado.equipo.trim().isEmpty
        ? 'Sin equipo asignado'
        : empleado.equipo.trim();

    // Leandro: Incluir el área evita mezclar equipos de áreas distintas con igual nombre.
    final clave = '${empleado.area}::$nombreEquipo';

    // Leandro: Si la clave no existe, crea una lista vacía; luego agrega esta persona.
    agrupadoPorEquipo.putIfAbsent(clave, () => []).add(cumplimiento);
  }

  final equipos = <EquipoGlobalViewModel>[];

  // Leandro: Segundo recorrido: convertimos cada grupo en un resumen para su tarjeta.
  agrupadoPorEquipo.forEach((clave, miembros) {
    // Leandro: Cada grupo tiene al menos una persona. Se usa la primera como referencia
    // Leandro: de área, nombre y gerente; el código toma su gerente como líder del grupo.
    final primerMiembro = miembros.first.empleado;
    final nombreEquipo = primerMiembro.equipo.trim().isEmpty
        ? 'Sin equipo asignado'
        : primerMiembro.equipo.trim();

    // Leandro: fold suma desde 0 las horas de los miembros. double permite decimales.
    // Leandro: Ejemplo: 4 + 2 horas realizadas, sobre 8 + 8 objetivo, da 37,5 %.
    final horasRealizadas = miembros.fold<double>(
      0,
      (total, miembro) => total + miembro.totalHorasCompletadas,
    );

    final horasObjetivo = miembros.fold<double>(
      0,
      (total, miembro) => total + miembro.totalHorasRequeridas,
    );

    // Leandro: Convención actual: sin horas objetivo se devuelve 100, evitando dividir por 0.
    final porcentajeCumplimiento = horasObjetivo == 0
        ? 100.0
        : (horasRealizadas / horasObjetivo) * 100;

    final cantidadIntegrantes = miembros.length;

    // Leandro: Se crea un objeto por equipo. where(...).length cuenta a las personas
    // Leandro: que cumplen su objetivo individual, según el servicio de cumplimiento.
    equipos.add(
      EquipoGlobalViewModel(
        id: _crearTeamId(primerMiembro.area, nombreEquipo),
        nombre: nombreEquipo,
        area: primerMiembro.area,
        lider: primerMiembro.gerente.trim().isEmpty
            ? 'Sin líder asignado'
            : primerMiembro.gerente,
        cantidadIntegrantes: cantidadIntegrantes,
        integrantesEnObjetivo: miembros
            .where((miembro) => miembro.cumpleObjetivo)
            .length,
        horasRealizadas: horasRealizadas,
        horasObjetivo: horasObjetivo,
        promedioPorColaborador: cantidadIntegrantes == 0
            ? 0
            : horasRealizadas / cantidadIntegrantes,
        porcentajeCumplimiento: porcentajeCumplimiento,
        // Leandro: Reutilizamos la regla de semáforo existente en metricas_providers.dart.
        semaforo: EstadoSemaforo.desdePorcentaje(porcentajeCumplimiento),
      ),
    );
  });

  // Leandro: La lista completa se entrega ordenada por nombre.
  equipos.sort((a, b) => a.nombre.compareTo(b.nombre));

  return equipos;
});

/// Leandro: Combina la lista completa con búsqueda, área y estado.
/// Leandro: Al cambiar un filtro, deriva un resultado nuevo de los equipos ya cargados.
final equiposGlobalFiltradosProvider =
    Provider<AsyncValue<List<EquipoGlobalViewModel>>>((ref) {
      // Leandro: Cada watch declara una dependencia: sus cambios recalculan este resultado.
      final areaSeleccionada = ref.watch(filtroAreaEquipoProvider);
      final estadoSeleccionado = ref.watch(filtroEstadoEquipoProvider);
      final equiposAsync = ref.watch(equiposGlobalProvider);
      // Leandro: Normalizamos el texto para ignorar mayúsculas y espacios en los extremos.
      final query = ref.watch(busquedaEquipoProvider).trim().toLowerCase();

      // Leandro: whenData transforma sólo el resultado; conserva carga y error si los hay.
      return equiposAsync.whenData((equipos) {
        // Leandro: where elige coincidencias sin modificar ni borrar la lista original.
        return equipos.where((equipo) {
          // Leandro: || significa "o": basta coincidir en nombre, área o líder.
          // Leandro: Una búsqueda vacía permite que pase cualquier equipo.
          final coincideBusqueda = query.isEmpty ||
              equipo.nombre.toLowerCase().contains(query) ||
              equipo.area.toLowerCase().contains(query) ||
              equipo.lider.toLowerCase().contains(query);

          final coincideArea =
              areaSeleccionada == null || equipo.area == areaSeleccionada;
          final coincideEstado =
              estadoSeleccionado == null || equipo.semaforo == estadoSeleccionado;

          // Leandro: && significa "y": deben cumplirse los tres filtros a la vez.
          // Leandro: toList materializa las coincidencias como una nueva lista.
          return coincideBusqueda && coincideArea && coincideEstado;
        }).toList();
      });
    });

// Leandro: Identificador derivado de los nombres. La navegación actual de EquipoCard
// Leandro: utiliza área y equipo en la ruta, no este id.
String _crearTeamId(String area, String equipo) {
  return '${_normalizarId(area)}-${_normalizarId(equipo)}';
}

// Leandro: Convierte el nombre a minúsculas y sustituye grupos fuera de a-z/0-9 por guiones.
// Leandro: El último reemplazo elimina los guiones que queden en los extremos.
String _normalizarId(String valor) {
  return valor
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

// Leandro: A partir de aquí están los providers compartidos de Áreas y del detalle.
// Leandro: equiposResumenProvider agrupa por área y detalleEquipoProvider la desarrolla.
// Leandro: detalleEquipoGeneralProvider obtiene los miembros que muestra equipo.dart.
// Listado consolidado de todos los equipos
final equiposResumenProvider = FutureProvider<List<ResumenEquipoViewModel>>((
  ref,
) async {
  final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
  final query = ref.watch(busquedaEquipoProvider).toLowerCase();

  final agrupado = <String, List<CumplimientoEmpleado>>{};
  for (final item in cumplimientos) {
    agrupado.putIfAbsent(item.empleado.area, () => []).add(item);
  }

  final lista = <ResumenEquipoViewModel>[];

  agrupado.forEach((area, miembros) {
    final totalIntegrantes = miembros.length;
    final integrantesCumplen = miembros.where((m) => m.cumpleObjetivo).length;
    final horasRealizadas = miembros.fold<double>(
      0.0,
      (acc, item) => acc + item.totalHorasCompletadas,
    );
    final horasRequeridas = miembros.fold<double>(
      0.0,
      (acc, item) => acc + item.totalHorasRequeridas,
    );

    final porcentaje = horasRequeridas == 0
        ? 100.0
        : (horasRealizadas / horasRequeridas) * 100;
    final equiposGenerales =
        miembros
            .map((miembro) => miembro.empleado.equipo.trim())
            .where((equipo) => equipo.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    lista.add(
      ResumenEquipoViewModel(
        nombreArea: area,
        cantidadIntegrantes: totalIntegrantes,
        integrantesCumplen: integrantesCumplen,
        horasTotalesRealizadas: horasRealizadas,
        horasTotalesRequeridas: horasRequeridas,
        porcentajeCumplimiento: porcentaje,
        semaforo: EstadoSemaforo.desdePorcentaje(porcentaje),
        equiposGenerales: equiposGenerales,
      ),
    );
  });

  return lista
      .where(
        (area) =>
            area.nombreArea.toLowerCase().contains(query) ||
            area.equiposGenerales.any(
              (equipo) => equipo.toLowerCase().contains(query),
            ),
      )
      .toList();
});

// Detalle de un equipo particular por su nombre/área
final detalleEquipoProvider =
    FutureProvider.family<DetalleEquipoViewModel, String>((
      ref,
      nombreArea,
    ) async {
      final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
      final areas = await ref.watch(equiposResumenProvider.future);

      final resumen = areas.firstWhere(
        (e) => e.nombreArea.toLowerCase() == nombreArea.toLowerCase(),
        orElse: () => throw Exception('Equipo no encontrado'),
      );

      final miembros = cumplimientos
          .where(
            (c) => c.empleado.area.toLowerCase() == nombreArea.toLowerCase(),
          )
          .toList();
      final miembrosPorEquipo = <String, List<CumplimientoEmpleado>>{};
      for (final miembro in miembros) {
        final equipo = miembro.empleado.equipo.trim().isEmpty
            ? 'Sin equipo asignado'
            : miembro.empleado.equipo.trim();
        miembrosPorEquipo.putIfAbsent(equipo, () => []).add(miembro);
      }

      return DetalleEquipoViewModel(
        nombreArea: resumen.nombreArea,
        resumen: resumen,
        miembros: miembros,
        miembrosPorEquipo: miembrosPorEquipo,
      );
    });

final detalleEquipoGeneralProvider =
    FutureProvider.family<
      DetalleEquipoGeneralViewModel,
      ({String area, String equipo})
    >((ref, params) async {
      final cumplimientos = await ref.watch(cumplimientoGlobalProvider.future);
      final miembros = cumplimientos.where((cumplimiento) {
        return cumplimiento.empleado.area.toLowerCase() ==
                params.area.toLowerCase() &&
            cumplimiento.empleado.equipo.toLowerCase() ==
                params.equipo.toLowerCase();
      }).toList();

      if (miembros.isEmpty) {
        throw Exception('Equipo general no encontrado');
      }

      return DetalleEquipoGeneralViewModel(
        nombreArea: params.area,
        nombreEquipo: params.equipo,
        miembros: miembros,
      );
    });
