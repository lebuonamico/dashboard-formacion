import 'dart:async';

import 'package:app_finnegans/domain/servicios/asistente_contexto_service.dart';
import 'package:app_finnegans/domain/servicios/dashboard_kpis_service.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final iaContextoRealProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('IA_CONTEXTO_REAL', defaultValue: true),
);
final asistenteContextoServiceProvider = Provider<AsistenteContextoService>(
  (ref) => AsistenteContextoService(),
);

/// Solo se ejecuta al enviar. El snapshot reutiliza providers y servicios de las
/// pantallas, con sus mismos datos; no cambia filtros ni necesita otra sesión.
final prepararContextoIaProvider =
    Provider<Future<ContextoAsistente> Function(DestinoAsistente, String)>(
      (ref) =>
          (destino, pregunta) => _preparar(
            ref,
            destino,
            pregunta,
          ).timeout(const Duration(seconds: 30)),
    );

Future<ContextoAsistente> _preparar(
  Ref ref,
  DestinoAsistente destino,
  String pregunta,
) async {
  final service = ref.read(asistenteContextoServiceProvider);
  final dinamico = ref.read(iaContextoRealProvider);
  final visible = PeriodoAsistente(
    anio: ref.read(filtroAnioPeriodoProvider),
    mes: ref.read(filtroMesPeriodoProvider),
    anual: ref.read(alcancePeriodoProvider) == AlcancePeriodo.anual,
  );
  final consulta = service.planificar(pregunta, destino, visible);
  final datos = <String, Object?>{'notas_alcance': <String>[]};
  final notas = datos['notas_alcance'] as List<String>;
  if (!dinamico || consulta.tema == TemaAsistente.conceptual) {
    datos['disponibilidad'] = dinamico
        ? 'Consulta conceptual; no se solicitaron indicadores.'
        : 'Contexto dinámico deshabilitado. No se enviaron indicadores ni ejemplos estáticos.';
    return service.preparar(consulta, datos, dinamico: dinamico);
  }
  if (consulta.tema == TemaAsistente.importacion) {
    datos['importaciones'] = {
      'orden': ['Nómina', 'Cursos', 'Horas CRM', 'Finalizaciones LMS'],
      'nomina_cursos':
          'Snapshot por archivo: activa presentes e inactiva ausentes sin borrado físico; no aceptar una foto vacía.',
      'crm':
          'UPSERT por transacción; resuelve curso por nombre normalizado; no elimina ausentes.',
      'lms':
          'UPSERT por legajo+curso; no elimina ausentes ni interpreta ausencia como no finalización.',
      'auditoria':
          'Registra resultado y errores; luego refresca providers. Un fallo de refresh no implica que no se hayan guardado los datos.',
      'limite':
          'Sin contenido de archivos ni historial de importaciones. No puede ejecutar cargas.',
    };
    return service.preparar(consulta, datos, dinamico: true);
  }
  if (consulta.periodos.isEmpty) {
    return service.preparar(consulta, datos, dinamico: true);
  }
  if (consulta.acumulado) {
    if (consulta.tema == TemaAsistente.general) {
      await _agregarAcumulado(ref, consulta, datos, service);
    } else {
      notas.add(
        'El acumulado por rango está disponible para el cumplimiento global de la organización desde el Dashboard. No se envió un total global como si correspondiera al área, equipo o perfil seleccionado.',
      );
    }
    return service.preparar(consulta, datos, dinamico: true);
  }
  if (consulta.tema == TemaAsistente.cursos && destino.legajo == null) {
    final cursos = await ref.read(cursosProvider.future);
    datos['catalogo'] = service.catalogo(cursos, pregunta);
    notas.add(
      'No hay perfil seleccionado. Recomendaciones generales, no personalizadas. El catálogo no está historizado por período.',
    );
    return service.preparar(consulta, datos, dinamico: true);
  }

  final resultados = <Map<String, Object?>>[];
  if (consulta.evolucion) {
    notas.add(
      'La serie enviada es global de la organización; no es una evolución individual ni del equipo o área seleccionados.',
    );
  }
  for (final periodo in consulta.periodos) {
    final usaGrupos =
        consulta.evolucion ||
        consulta.tema == TemaAsistente.general ||
        consulta.tema == TemaAsistente.areas ||
        consulta.tema == TemaAsistente.equipos;
    final scope = await _snapshot(ref, periodo, requiereHistorial: usaGrupos);
    final resultado = <String, Object?>{'periodo': periodo.toJson()};
    resultados.add(resultado);
    try {
      final hayDatos = await scope.read(hayDatosEquiposPeriodoProvider.future);
      resultado['tiene_datos'] = hayDatos;
      if (!hayDatos) {
        resultado['alcance'] =
            'No hay movimientos CRM ni LMS en este período. No evaluar incumplimiento ni inventar ceros.';
        if (consulta.tema == TemaAsistente.cursos) {
          resultado['catalogo'] = service.catalogo(
            await scope.read(cursosProvider.future),
            pregunta,
          );
          notas.add(
            'Sin datos del período para personalizar; se envía catálogo actual sin historial.',
          );
        }
        continue;
      }
      final resumen = usaGrupos
          ? await scope.read(resumenEquiposPeriodoProvider.future)
          : null;
      if (resumen != null && resumen.colaboradores == 0) {
        resultado['disponibilidad'] =
            'Hay movimientos pero no colaboradores evaluables; no hay un KPI de cumplimiento para mostrar.';
        continue;
      }
      if (resumen != null) resultado['global'] = _global(resumen);
      if (consulta.evolucion) {
        (resultado['global'] as Map).removeWhere(
          (k, _) => !{
            'completo',
            'colaboradores',
            'horas_validas',
            'horas_objetivo',
            'cumplimiento_pct',
          }.contains(k),
        );
        continue;
      }
      switch (consulta.tema) {
        case TemaAsistente.general:
          final cumplimientos = await scope.read(
            cumplimientoDashboardProvider.future,
          );
          final cargas = await scope.read(cargasDashboardProvider.future);
          final meses = await scope.read(
            mesesEvaluadosDashboardProvider.future,
          );
          final kpis = const DashboardKpisService().calcular(
            cumplimientos: cumplimientos,
            cargas: cargas,
            mesesEvaluados: meses,
          );
          resultado['dashboard'] = {
            'completo': true,
            'colaboradores': kpis.colaboradores,
            'capacitandose': kpis.capacitandose,
            'horas_declaradas_crm': kpis.horasDeclaradas,
            'meses_evaluados': kpis.mesesEvaluados,
            'ritmo_mensual_hs_por_persona': kpis.ritmoMensual,
            'proyeccion_anual_hs_por_persona': kpis.proyeccionAnual,
          };
          if (RegExp(
            r'categor|negocio|blanda|libre|dictad',
          ).hasMatch(service.normalizar(pregunta))) {
            resultado['horas_validas_por_categoria'] = {
              'negocio': resumen!.horasNegocio,
              'blandas': resumen.horasBlandas,
              'libres': resumen.horasLibres,
              'dictado': resumen.horasDictado,
            };
          }
        case TemaAsistente.areas:
          final areas = await scope.read(resumenAreasPeriodoProvider.future);
          var lista = areas.areas.toList();
          final q = service.normalizar(pregunta);
          final explicitas = lista
              .where((a) => _menciona(q, a.nombre, service))
              .toList();
          if (explicitas.isNotEmpty) {
            lista = explicitas;
          } else if (destino.area != null &&
              !RegExp(r'compar|menor|mayor|todas|ranking').hasMatch(q)) {
            lista = lista
                .where(
                  (a) =>
                      service.normalizar(a.nombre) ==
                      service.normalizar(destino.area!),
                )
                .toList();
          }
          if (q.contains('critic')) {
            lista = lista.where((a) => a.semaforo.label == 'Crítico').toList();
          }
          lista.sort(
            (a, b) => q.contains('mayor') || q.contains('mejor')
                ? b.porcentajeCumplimiento.compareTo(a.porcentajeCumplimiento)
                : a.porcentajeCumplimiento.compareTo(b.porcentajeCumplimiento),
          );
          resultado['areas'] = service.seleccion(
            lista
                .map(
                  (a) => <String, Object?>{
                    'area': a.nombre,
                    'colaboradores': a.cantidadIntegrantes,
                    'personas_en_objetivo': a.integrantesEnObjetivo,
                    'horas_validas': a.horasRealizadas,
                    'horas_objetivo': a.horasObjetivo,
                    'cumplimiento_pct': a.porcentajeCumplimiento,
                    'estado': a.semaforo.label,
                  },
                )
                .toList(),
            total: lista.length,
            criterio:
                'Áreas calculadas; orden por cumplimiento, filtro según pregunta/selección.',
            max: service.soloTotales(pregunta) ? 0 : 12,
          );
          if (destino.area != null) {
            notas.add(
              'El global corresponde a toda la organización; la lista identifica el área seleccionada cuando aplica.',
            );
          }
        case TemaAsistente.equipos:
          var lista = resumen!.equipos.toList();
          final q = service.normalizar(pregunta);
          final explicitos = lista
              .where((e) => _menciona(q, e.nombre, service))
              .toList();
          final areasExplicitas = lista
              .map((e) => e.area)
              .where((a) => _menciona(q, a, service))
              .toSet();
          final comparacion = RegExp(
            r'compar|otros|resto|todos|que equipos|cuales|ranking|menor|mayor',
          ).hasMatch(q);
          if (destino.equipo != null) {
            final seleccionado = lista
                .where(
                  (e) =>
                      service.normalizar(e.nombre) ==
                          service.normalizar(destino.equipo!) &&
                      service.normalizar(e.area) ==
                          service.normalizar(destino.area ?? ''),
                )
                .firstOrNull;
            if (seleccionado != null) {
              resultado['equipo_seleccionado'] = _equipo(seleccionado);
            } else {
              notas.add(
                'El equipo seleccionado no tiene integrantes evaluables en este período; no implica que no exista en la base.',
              );
            }
          }
          if (explicitos.isNotEmpty) {
            lista = explicitos;
          } else if (areasExplicitas.isNotEmpty) {
            lista = lista
                .where((e) => areasExplicitas.contains(e.area))
                .toList();
          } else if (destino.area != null && !comparacion) {
            lista = lista
                .where(
                  (e) =>
                      service.normalizar(e.area) ==
                      service.normalizar(destino.area!),
                )
                .toList();
            if (destino.equipo != null) {
              lista = lista
                  .where(
                    (e) =>
                        service.normalizar(e.nombre) ==
                        service.normalizar(destino.equipo!),
                  )
                  .toList();
            }
          }
          if (q.contains('critic')) {
            lista = lista
                .where((e) => e.estado == EstadoEquipo.critico)
                .toList();
          } else if (q.contains('riesgo')) {
            lista = lista
                .where((e) => e.estado == EstadoEquipo.enRiesgo)
                .toList();
          } else if (q.contains('en objetivo')) {
            lista = lista
                .where((e) => e.estado == EstadoEquipo.enObjetivo)
                .toList();
          }
          if (RegExp(r'menor|mayor|mejor|peor|compar').hasMatch(q)) {
            lista.sort(
              (a, b) => q.contains('mayor') || q.contains('mejor')
                  ? b.porcentajeCumplimiento.compareTo(a.porcentajeCumplimiento)
                  : a.porcentajeCumplimiento.compareTo(
                      b.porcentajeCumplimiento,
                    ),
            );
          }
          resultado['equipos'] = service.seleccion(
            lista.map(_equipo).toList(),
            total: lista.length,
            criterio:
                'Estado calculado por EquiposService; filtro de pregunta, prioridad o cumplimiento.',
            max: service.soloTotales(pregunta) ? 0 : 12,
          );
        case TemaAsistente.persona || TemaAsistente.cursos:
          final empleados = await scope.read(empleadosProvider.future);
          final q = service.normalizar(pregunta);
          final coincidencias = empleados
              .where((e) => _menciona(q, e.nombreCompleto, service))
              .toList();
          final legajo = coincidencias.length == 1
              ? coincidencias.single.legajo
              : destino.legajo;
          if (legajo == null) {
            notas.add(
              'No hay una persona identificada de forma inequívoca. Seleccioná su perfil o indicá el nombre completo. No usar la cuenta autenticada como perfil.',
            );
          } else {
            final detalle = await scope.read(
              detalleEmpleadoProvider(legajo).future,
            );
            if (detalle == null) {
              notas.add(
                'No se encontró el perfil seleccionado en la nómina disponible.',
              );
            } else {
              resultado['perfil_seleccionado'] = service.persona(
                detalle.cumplimiento,
              );
              notas.add(
                'El perfil conserva el alcance de su pantalla: usa atributos actuales de nómina y no reconstruye la elegibilidad histórica de Equipos.',
              );
              if (periodo.anual) {
                notas.add(
                  'El perfil individual usa el objetivo mensual actual ×12 y sus propios filtros, igual que su pantalla; no equivale al acumulado histórico anual de Equipos.',
                );
              }
              if (consulta.tema == TemaAsistente.cursos) {
                resultado['catalogo'] = service.catalogo(
                  await scope.read(cursosProvider.future),
                  pregunta,
                  perfil: detalle.cumplimiento,
                  finalizados: detalle.cursosFinalizados,
                );
                notas.add(
                  'Catálogo actual, sin historización por período. No se enviaron correo, legajo ni instructor.',
                );
              }
            }
          }
        case TemaAsistente.conceptual || TemaAsistente.importacion:
          break;
      }
    } catch (_) {
      resultado['disponibilidad'] =
          'Preparación incompleta: los bloques presentes conservan su alcance. Solo los campos ausentes no están disponibles en esta consulta; no implican ausencia de registros.';
    } finally {
      scope.dispose();
    }
  }
  datos['resultados'] = resultados;
  datos['notas_alcance'] = notas.toSet().toList();
  return service.preparar(consulta, datos, dinamico: true);
}

Future<void> _agregarAcumulado(
  Ref ref,
  ConsultaAsistente consulta,
  Map<String, Object?> datos,
  AsistenteContextoService service,
) async {
  String clave(PeriodoAsistente p) =>
      '${p.anio}-${p.mes.toString().padLeft(2, '0')}';
  final meses = <Map<String, Object?>>[];
  final detalle = <Map<String, Object?>>[];
  final evaluados = <ResumenEquiposPeriodo>[];
  var incompleto = false;
  for (final periodo in consulta.periodos) {
    final mes = <String, Object?>{
      'periodo': clave(periodo),
      'estado': 'no_consultado',
    };
    meses.add(mes);
    ProviderContainer? scope;
    try {
      scope = await _snapshot(ref, periodo, requiereHistorial: true);
      if (!await scope.read(hayDatosEquiposPeriodoProvider.future)) {
        mes['estado'] = 'sin_datos';
        continue;
      }
      final resumen = await scope.read(resumenEquiposPeriodoProvider.future);
      if (resumen.colaboradores == 0) {
        mes['estado'] = 'sin_colaboradores_evaluables';
        continue;
      }
      evaluados.add(resumen);
      mes['estado'] = 'evaluado';
      detalle.add({
        'periodo': clave(periodo),
        'horas_validas': resumen.horasRealizadas,
        'horas_objetivo': resumen.horasObjetivo,
        'cumplimiento_pct': resumen.cumplimientoGlobal,
      });
    } catch (_) {
      // Un fallo de lectura o de cálculo no equivale a un mes sin registros.
      incompleto = true;
    } finally {
      scope?.dispose();
    }
  }
  final total = !incompleto && evaluados.isNotEmpty
      ? const DashboardKpisService().acumularCumplimiento(evaluados)
      : null;
  datos['acumulado_solicitado'] = {
    'alcance': 'global_organizacion',
    'desde': clave(consulta.periodos.first),
    'hasta': clave(consulta.periodos.last),
    'completo': !incompleto,
    'estado': incompleto
        ? 'incompleto'
        : total == null
        ? 'sin_meses_evaluables'
        : 'disponible',
    'meses_solicitados': meses.length,
    'meses_evaluados': evaluados.length,
    'meses': meses,
    if (total != null) ...{
      'horas_validas': total.horasValidas,
      'horas_objetivo': total.horasObjetivo,
      'cumplimiento_pct': total.cumplimiento,
    },
  };
  datos['desglose_mensual'] = service.seleccion(
    detalle,
    total: detalle.length,
    criterio: 'Indicadores mensuales evaluados; el acumulado no se recorta.',
  );
  (datos['notas_alcance'] as List<String>).add(
    'El rango incluye ambos extremos. Se acumulan solo meses con datos CRM o LMS y colaboradores evaluables, con elegibilidad histórica y topes mensuales. sin_datos y sin_colaboradores_evaluables se excluyen sin asignarles 0%. no_consultado indica un fallo al obtener o calcular indicadores: impide publicar el total del rango.',
  );
}

Map<String, Object?> _global(ResumenEquiposPeriodo r) => {
  'completo': true,
  'colaboradores': r.colaboradores,
  'horas_validas': r.horasRealizadas,
  'horas_objetivo': r.horasObjetivo,
  'cumplimiento_pct': r.cumplimientoGlobal,
  'equipos': r.totalEquipos,
  'en_objetivo': r.enObjetivo,
  'en_riesgo': r.enRiesgo,
  'criticos': r.criticos,
};
Map<String, Object?> _equipo(TeamOverview e) => {
  'equipo': e.nombre,
  'area': e.area,
  'integrantes': e.cantidadIntegrantes,
  'personas_en_objetivo': e.integrantesEnObjetivo,
  'horas_validas': e.horasRealizadas,
  'horas_objetivo': e.horasObjetivo,
  'cumplimiento_pct': e.porcentajeCumplimiento,
  'estado': e.estado.label,
};
bool _menciona(String q, String nombre, AsistenteContextoService s) {
  final n = s.normalizar(nombre);
  return n.length >= 3 && ' $q '.contains(' $n ');
}

Future<ProviderContainer> _snapshot(
  Ref ref,
  PeriodoAsistente periodo, {
  required bool requiereHistorial,
}) async {
  final empleadosF = ref.read(empleadosProvider.future);
  final historialF = requiereHistorial
      ? ref.read(empleadoHistorialProvider.future)
      : Future.value(null);
  final cursosF = ref.read(cursosProvider.future);
  final cargasF = ref.read(cargasDeHorasCRMProvider.future);
  final certificacionesF = ref.read(certificacionesMoodleProvider.future);
  final estructuraF = ref.read(estructuraProvider.future);
  final alcanceF = ref.read(alcanceUsuarioProvider.future);
  final equiposService = ref.read(equiposServiceProvider);
  final cumplimientoServiceF = ref.read(cumplimientoServiceProvider.future);
  final sesion = ref.read(sesionDatosProvider);
  final (
    empleados,
    historial,
    cursos,
    cargas,
    certificaciones,
    estructura,
    alcanceUsuario,
    cumplimientoService,
  ) = await (
    empleadosF,
    historialF,
    cursosF,
    cargasF,
    certificacionesF,
    estructuraF,
    alcanceF,
    cumplimientoServiceF,
  ).wait;
  return ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      // El contenedor no tiene padre: sin esto armaría otra sesión sin rol y
      // el alcance lo dejaría sin colaboradores.
      sesionDatosProvider.overrideWithValue(sesion),
      estructuraProvider.overrideWith((_) async => estructura),
      alcanceUsuarioProvider.overrideWith((_) async => alcanceUsuario),
      empleadosProvider.overrideWith((_) async => empleados),
      empleadoHistorialProvider.overrideWith((_) async => historial),
      cursosProvider.overrideWith((_) async => cursos),
      cargasDeHorasCRMProvider.overrideWith((_) async => cargas),
      certificacionesMoodleProvider.overrideWith((_) async => certificaciones),
      equiposServiceProvider.overrideWithValue(equiposService),
      cumplimientoServiceProvider.overrideWith(
        (_) async => cumplimientoService,
      ),
      alcancePeriodoProvider.overrideWith(
        (_) => periodo.anual ? AlcancePeriodo.anual : AlcancePeriodo.mensual,
      ),
      filtroMesPeriodoProvider.overrideWith((_) => periodo.mes),
      filtroAnioPeriodoProvider.overrideWith((_) => periodo.anio),
      cargasDashboardProvider.overrideWith(
        (_) async => equiposService.periods.filterTimeEntriesByPeriod(
          timeEntries: cargas,
          year: periodo.anio,
          month: periodo.mes,
          isAnnual: periodo.anual,
        ),
      ),
    ],
  );
}
