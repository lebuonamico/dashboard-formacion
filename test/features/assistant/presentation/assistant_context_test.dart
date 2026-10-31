import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/presentation/assistant_labels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/assistant_fixtures.dart';

const _july = {'anio': 2026, 'mes': 7, 'alcance': 'mensual'};

const _globalJuly = {
  'completo': true,
  'colaboradores': 8,
  'horas_validas': 37.0,
  'horas_objetivo': 64.0,
  'cumplimiento_pct': 57.8125,
  'equipos': 3,
  'en_objetivo': 1,
  'en_riesgo': 1,
  'criticos': 1,
};

const _quality = {
  'area': 'Calidad',
  'colaboradores': 3,
  'personas_en_objetivo': 0,
  'horas_validas': 1.0,
  'horas_objetivo': 24.0,
  'cumplimiento_pct': 4.166666666666666,
  'estado': 'Crítico',
};

const _frontend = {
  'equipo': 'Frontend Arquitectura & UI',
  'area': 'Desarrollo',
  'integrantes': 2,
  'personas_en_objetivo': 1,
  'horas_validas': 12.0,
  'horas_objetivo': 16.0,
  'cumplimiento_pct': 75.0,
  'estado': 'En riesgo',
};

const _teamsCriterion =
    'Estado calculado por EquiposService; filtro de pregunta, prioridad o cumplimiento.';
const _areasCriterion =
    'Áreas calculadas; orden por cumplimiento, filtro según pregunta/selección.';
const _profileNote =
    'El perfil conserva el alcance de su pantalla: usa atributos actuales de nómina y no reconstruye la elegibilidad histórica de Equipos.';

Map<String, Object?> _selection(List<Object?> items, String criterion) => {
  'total_coincidencias': items.length,
  'enviados': items.length,
  'criterio': criterion,
  'seleccion_parcial': false,
  'items': items,
};

void main() {
  group('Contexto del asistente con el seed de julio de 2026', () {
    test('general: global, dashboard y horas por categoría', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.dashboard),
        '¿Cómo viene el cumplimiento por categoría?',
      );

      expect(assistantContextLabel(context), 'Dashboard · datos del proyecto');
      expect(context.data, {
        'origen': origin,
        'pantalla': 'Dashboard',
        'tema': 'general',
        'notas_alcance': <String>[],
        'resultados': [
          {
            'periodo': _july,
            'tiene_datos': true,
            'global': _globalJuly,
            'dashboard': {
              'completo': true,
              'colaboradores': 8,
              'capacitandose': 7,
              'horas_declaradas_crm': 41.0,
              'meses_evaluados': 1,
              'ritmo_mensual_hs_por_persona': 4.625,
              'proyeccion_anual_hs_por_persona': 55.5,
            },
            'horas_validas_por_categoria': {
              'negocio': 8.0,
              'blandas': 14.0,
              'libres': 11.0,
              'dictado': 4.0,
            },
          },
        ],
      });
    });

    test('áreas: todas, de menor a mayor cumplimiento', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.areas),
        '¿Cómo vienen las áreas?',
      );

      expect(context.data, {
        'origen': origin,
        'pantalla': 'Áreas',
        'tema': 'areas',
        'notas_alcance': <String>[],
        'resultados': [
          {
            'periodo': _july,
            'tiene_datos': true,
            'global': _globalJuly,
            'areas': _selection([
              _quality,
              {
                'area': 'Desarrollo',
                'colaboradores': 5,
                'personas_en_objetivo': 4,
                'horas_validas': 36.0,
                'horas_objetivo': 40.0,
                'cumplimiento_pct': 90.0,
                'estado': 'En riesgo',
              },
            ], _areasCriterion),
          },
        ],
      });
    });

    test('áreas: la pregunta por críticas filtra el nivel', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.areas),
        '¿Qué áreas están críticas?',
      );

      final result = (context.data['resultados'] as List).single as Map;
      expect(result['areas'], _selection([_quality], _areasCriterion));
    });

    test('equipos: el equipo seleccionado y la lista de su área', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(
          AssistantModule.teamDetail,
          area: 'Desarrollo',
          team: 'Frontend Arquitectura & UI',
        ),
        '¿Cómo viene este equipo?',
      );

      expect(context.data, {
        'origen': origin,
        'pantalla': 'Detalle de equipo',
        'tema': 'equipos',
        'notas_alcance': <String>[],
        'resultados': [
          {
            'periodo': _july,
            'tiene_datos': true,
            'global': _globalJuly,
            'equipo_seleccionado': _frontend,
            'equipos': _selection([_frontend], _teamsCriterion),
          },
        ],
      });
    });

    test('equipos: la pregunta por riesgo filtra el estado', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.teams),
        '¿Qué equipos están en riesgo?',
      );

      expect(context.data['pantalla'], 'Equipos');
      expect(context.data['tema'], 'equipos');
      final result = (context.data['resultados'] as List).single as Map;
      expect(result['equipos'], _selection([_frontend], _teamsCriterion));
    });

    test('perfil: nombre, seniority y las cuatro categorías', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(
          AssistantModule.people,
          employeeId: 'EMP-005',
        ),
        '¿Cómo viene el colaborador seleccionado?',
      );

      expect(assistantContextLabel(context), 'Personas · datos del proyecto');
      expect(context.data, {
        'origen': origin,
        'pantalla': 'Personas',
        'tema': 'persona',
        'notas_alcance': [_profileNote],
        'resultados': [
          {
            'periodo': _july,
            'tiene_datos': true,
            'perfil_seleccionado': {
              'nombre': 'Valeria Ríos',
              'seniority': 'Senior 1',
              'horas_validas': 8.0,
              'horas_declaradas': 10.0,
              'horas_objetivo': 8.0,
              'cumplimiento_pct': 100.0,
              'cumple_objetivo': true,
              'categorias': {
                'Habilidades de negocio': {
                  'validas_aplicables': 0.0,
                  'objetivo': 0.0,
                },
                'Habilidades blandas': {
                  'validas_aplicables': 2.0,
                  'objetivo': 2.0,
                },
                'Libres / exploración': {
                  'validas_aplicables': 2.0,
                  'objetivo': 2.0,
                },
                'Dictado de capacitaciones': {
                  'validas_aplicables': 4.0,
                  'objetivo': 4.0,
                },
              },
            },
          },
        ],
      });
    });

    test('cursos con perfil: prioriza lo pendiente y excluye lo '
        'finalizado', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(
          AssistantModule.people,
          employeeId: 'EMP-006',
        ),
        '¿Qué cursos me recomendás?',
      );

      expect(context.data['tema'], 'cursos');
      expect(context.data['notas_alcance'], [
        _profileNote,
        'Catálogo actual, sin historización por período. No se enviaron correo, legajo ni instructor.',
      ]);
      final result = (context.data['resultados'] as List).single as Map;
      expect((result['perfil_seleccionado'] as Map)['seniority'], 'Junior 1');
      expect(result['catalogo'], {
        ..._selection(
          [
            for (final name in [
              'Estrategia y Modelos de Negocio',
              'Finanzas Básicas para Tech',
              'Negociación con Clientes',
            ])
              {
                'curso': name,
                'categoria': 'Habilidades de negocio',
                'rol': 'participante',
                'horas': 4.0,
              },
            {
              'curso': 'Exploración de Arquitecturas Serverless',
              'categoria': 'Libres / exploración',
              'rol': 'participante',
              'horas': 2.0,
            },
            {
              'curso': 'Formación de Instructores',
              'categoria': 'Dictado de capacitaciones',
              'rol': 'instructor',
              'horas': 4.0,
            },
          ],
          'Catálogo activo; prioriza categorías pendientes del perfil calculado. No garantiza cubrir todo el objetivo.',
        ),
        'activos_catalogo': 8,
        'finalizados_excluidos': true,
        'perfil_disponible': true,
      });
    });

    test('cursos sin perfil: el catálogo filtrado por categoría', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.courses),
        '¿Qué cursos de habilidades blandas hay?',
      );

      expect(context.data, {
        'origen': origin,
        'pantalla': 'Cursos',
        'tema': 'cursos',
        'notas_alcance': [
          'No hay perfil seleccionado. Recomendaciones generales, no personalizadas. El catálogo no está historizado por período.',
        ],
        'catalogo': {
          ..._selection(
            [
              for (final name in [
                'Comunicación Asertiva y Feedback',
                'Gestión del Tiempo y Priorización',
                'Trabajo en Equipo Remoto',
              ])
                {
                  'curso': name,
                  'categoria': 'Habilidades blandas',
                  'rol': 'participante',
                  'horas': 4.0,
                },
            ],
            'Catálogo activo por afinidad textual; falta perfil para personalizar.',
          ),
          'activos_catalogo': 8,
          'finalizados_excluidos': false,
          'perfil_disponible': false,
        },
      });
    });

    test('importación: solo las reglas, sin datos', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.settings),
        '¿Cómo funciona la importación de nómina?',
      );

      expect(
        assistantContextLabel(context),
        'Configuración · datos del proyecto',
      );
      expect(context.data, {
        'origen': origin,
        'pantalla': 'Configuración',
        'tema': 'importacion',
        'notas_alcance': <String>[],
        'importaciones': {
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
        },
      });
    });

    test('conceptual: sin indicadores', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.dashboard),
        '¿Qué significa cumplimiento?',
      );

      expect(context.data, {
        'origen': origin,
        'pantalla': 'Dashboard',
        'tema': 'conceptual',
        'notas_alcance': <String>[],
        'disponibilidad': 'Consulta conceptual; no se solicitaron indicadores.',
      });
    });

    test('contexto dinámico apagado: ayuda conceptual sin datos', () async {
      final context = await contextFor(
        seedContainer(dynamicContext: false),
        const AssistantDestination(AssistantModule.dashboard),
        '¿Cómo viene el cumplimiento?',
      );

      expect(assistantContextLabel(context), 'Dashboard · ayuda conceptual');
      expect(context.data, {
        'origen': origin,
        'pantalla': 'Dashboard',
        'tema': 'general',
        'notas_alcance': <String>[],
        'disponibilidad':
            'Contexto dinámico deshabilitado. No se enviaron indicadores ni ejemplos estáticos.',
      });
    });

    test('un mes sin movimientos no se evalúa', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.dashboard),
        '¿Cómo viene el cumplimiento en junio de 2026?',
      );

      expect(context.data['resultados'], [
        {
          'periodo': {'anio': 2026, 'mes': 6, 'alcance': 'mensual'},
          'tiene_datos': false,
          'alcance':
              'No hay movimientos CRM ni LMS en este período. No evaluar incumplimiento ni inventar ceros.',
        },
      ]);
    });

    test('acumulado de un rango: meses evaluados y sin datos', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.dashboard),
        '¿Cuál es el cumplimiento acumulado de junio a septiembre de 2026?',
      );

      Map<String, Object?> month(int month) => {
        'periodo': '2026-0$month',
        'horas_validas': 37.0,
        'horas_objetivo': 64.0,
        'cumplimiento_pct': 57.8125,
      };
      expect(context.data, {
        'origen': origin,
        'pantalla': 'Dashboard',
        'tema': 'general',
        'notas_alcance': [
          'El rango incluye ambos extremos. Se acumulan solo meses con datos CRM o LMS y colaboradores evaluables, con elegibilidad histórica y topes mensuales. sin_datos y sin_colaboradores_evaluables se excluyen sin asignarles 0%. no_consultado indica un fallo al obtener o calcular indicadores: impide publicar el total del rango.',
        ],
        'acumulado_solicitado': {
          'alcance': 'global_organizacion',
          'desde': '2026-06',
          'hasta': '2026-09',
          'completo': true,
          'estado': 'disponible',
          'meses_solicitados': 4,
          'meses_evaluados': 3,
          'meses': [
            {'periodo': '2026-06', 'estado': 'sin_datos'},
            for (final month in [7, 8, 9])
              {'periodo': '2026-0$month', 'estado': 'evaluado'},
          ],
          'horas_validas': 111.0,
          'horas_objetivo': 192.0,
          'cumplimiento_pct': 57.8125,
        },
        'desglose_mensual': _selection([
          month(7),
          month(8),
          month(9),
        ], 'Indicadores mensuales evaluados; el acumulado no se recorta.'),
      });
    });

    test('evolución: solo el global reducido de cada mes', () async {
      final context = await contextFor(
        seedContainer(),
        const AssistantDestination(AssistantModule.dashboard),
        '¿Cuál es la evolución del cumplimiento de julio a septiembre?',
      );

      expect(context.data, {
        'origen': origin,
        'pantalla': 'Dashboard',
        'tema': 'general',
        'notas': [
          'El año no se indicó: el rango comienza en 2026, seleccionado en la aplicación; si cruza diciembre continúa en el año siguiente.',
        ],
        'notas_alcance': [
          'La serie enviada es global de la organización; no es una evolución individual ni del equipo o área seleccionados.',
        ],
        'resultados': [
          for (final month in [7, 8, 9])
            {
              'periodo': {'anio': 2026, 'mes': month, 'alcance': 'mensual'},
              'tiene_datos': true,
              'global': {
                'completo': true,
                'colaboradores': 8,
                'horas_validas': 37.0,
                'horas_objetivo': 64.0,
                'cumplimiento_pct': 57.8125,
              },
            },
        ],
      });
    });

    test('anual: los meses con datos y legajos únicos', () async {
      final context = await contextFor(
        seedContainer(scope: PeriodScope.annual),
        const AssistantDestination(AssistantModule.dashboard),
        '¿Cómo viene el cumplimiento anual 2026?',
      );

      expect(context.data['resultados'], [
        {
          'periodo': {'anio': 2026, 'alcance': 'anual'},
          'tiene_datos': true,
          'global': {
            ..._globalJuly,
            'horas_validas': 111.0,
            'horas_objetivo': 192.0,
          },
          'dashboard': {
            'completo': true,
            'colaboradores': 8,
            'capacitandose': 7,
            'horas_declaradas_crm': 123.0,
            'meses_evaluados': 3,
            'ritmo_mensual_hs_por_persona': 4.625,
            'proyeccion_anual_hs_por_persona': 55.5,
          },
        },
      ]);
    });
  }, skip: SupabaseConfig.enabled);
}
