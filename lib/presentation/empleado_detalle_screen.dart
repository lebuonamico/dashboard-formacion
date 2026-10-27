import 'package:app_finnegans/presentation/widgets/shared/error_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/proyeccion_empleado_card.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/etiqueta_color.dart';
import 'package:app_finnegans/presentation/widgets/shared/seniority_chip.dart';
import 'package:app_finnegans/presentation/widgets/shared/periodo_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

class EmpleadoDetalleScreen extends ConsumerWidget {
  final String legajo;

  const EmpleadoDetalleScreen({super.key, required this.legajo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalleAsync = ref.watch(detalleEmpleadoProvider(legajo));
    final alcance = ref.watch(alcancePeriodoProvider);
    final mes = ref.watch(filtroMesPeriodoProvider);
    final anio = ref.watch(filtroAnioPeriodoProvider);
    final periodoTexto = alcance == AlcancePeriodo.anual
        ? 'Año $anio'
        : '${nombreMes(mes)} $anio';
    final hayDatosPeriodo =
        ref.watch(hayDatosEquiposPeriodoProvider).value ?? true;

    final estiloSeccion = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: context.colorScheme.onSurface,
    );

    return Scaffold(
      body: Column(
        children: [
          AppTopBar(
            title: 'Perfil del colaborador',
            onBack: () => context.pop(),
          ),

          // Contenido
          Expanded(
            child: detalleAsync.when(
              // Al cambiar el período mantiene los datos previos en pantalla.
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorDataState(
                title: 'No pudimos cargar el colaborador',
                error: err,
              ),
              data: (detalle) => FadeIn(
                child: (() {
                  if (detalle == null) {
                    return const Center(child: Text('Empleado no encontrado.'));
                  }

                  final emp = detalle.empleado;
                  final cump = detalle.cumplimiento;

                  return ListView(
                    padding: paddingPantalla,
                    children: [
                      // Cabecera con datos del empleado
                      _buildHeaderEmpleado(
                        context,
                        emp,
                        cump,
                        mostrarCumplimiento: hayDatosPeriodo,
                      ),
                      const SizedBox(height: 16),

                      // Filtro de período global
                      const PeriodoFilterPanel(),
                      const SizedBox(height: 24),

                      if (!hayDatosPeriodo) ...[
                        EmptyDataState.periodoSinDatos(
                          periodo: etiquetaPeriodo(alcance, mes, anio),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Desglose de cumplimiento por categoría
                        Text(
                          'Desglose del plan de formación ($periodoTexto)',
                          style: estiloSeccion,
                        ),
                        const SizedBox(height: 12),
                        _buildGridCategorias(context, cump),
                        const SizedBox(height: 24),

                        if (ref.watch(proyeccionEmpleadoProvider(legajo)).value
                            case final proyeccion?) ...[
                          Text('Proyección a fin de año', style: estiloSeccion),
                          const SizedBox(height: 12),
                          ProyeccionEmpleadoCard(
                            proyeccion: proyeccion,
                            anio: anio,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Cursos del período: Moodle y CRM
                        Text(
                          'Cursos del período ($periodoTexto)',
                          style: estiloSeccion,
                        ),
                        const SizedBox(height: 12),
                        _buildColumnasCursos(context, detalle),
                        const SizedBox(height: 24),
                      ],

                      // Cursos Dictados (si aplica al seniority)
                      if ((cump.horasRequeridas[TipoCurso
                                      .dictadoCapacitaciones] ??
                                  0) >
                              0 ||
                          detalle.cursosDictados.isNotEmpty) ...[
                        Text(
                          'Cursos dictados como instructor',
                          style: estiloSeccion,
                        ),
                        const SizedBox(height: 12),
                        _buildTablaDictados(context, detalle.cursosDictados),
                      ],
                    ],
                  );
                })(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderEmpleado(
    BuildContext context,
    Empleado emp,
    CumplimientoEmpleado cump, {
    required bool mostrarCumplimiento,
  }) {
    final cs = context.colorScheme;
    final estadoCumplimiento = cump.cumpleObjetivo
        ? context.colores.exito
        : context.colores.advertencia;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.panel(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: cs.primary,
            child: Text(
              emp.nombre.trim().isEmpty
                  ? '?'
                  : emp.nombre.trim().substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 28,
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${emp.nombre} ${emp.apellido}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SeniorityChip(seniority: emp.seniority),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Área de ${emp.area} · Legajo: ${emp.legajo}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  emp.mail,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _DatoEmpleado(
                      label: 'Equipo',
                      value: _mostrarDato(emp.equipo),
                    ),
                    _DatoEmpleado(
                      label: 'Gerente',
                      value: _mostrarDato(emp.gerente),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Estado de Cumplimiento Global
          if (mostrarCumplimiento)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: estadoCumplimiento.fondo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${cump.totalHorasValidas.toStringAsFixed(0)} / ${cump.totalHorasRequeridas.toStringAsFixed(0)} hs LMS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: estadoCumplimiento.texto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cump.cumpleObjetivo ? 'Objetivo cumplido' : 'En progreso',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: estadoCumplimiento.texto,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CRM declaró ${cump.totalHorasDeclaradas.toStringAsFixed(0)} hs',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _mostrarDato(String valor) => valor.trim().isEmpty ? '-' : valor;

  Widget _buildGridCategorias(BuildContext context, CumplimientoEmpleado cump) {
    return Row(
      children: TipoCurso.values.map((tipo) {
        final completadas = cump.horasValidas[tipo] ?? 0.0;
        final declaradas = cump.horasDeclaradas[tipo] ?? 0.0;
        final requeridas = cump.horasRequeridas[tipo] ?? 0.0;
        final requerida = requeridas > 0;
        final cumple = requerida && completadas >= requeridas;
        // Libres y Dictado no existen en el LMS: se cumplen con horas CRM.
        final fuente =
            tipo == TipoCurso.libresExploracion ||
                tipo == TipoCurso.dictadoCapacitaciones
            ? 'CRM'
            : 'LMS';

        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: context.panel(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  requerida
                      ? '${completadas.toStringAsFixed(0)} / ${requeridas.toStringAsFixed(0)} hs $fuente'
                      : 'No requerida',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: !requerida
                        ? context.colorScheme.onSurfaceVariant
                        : cumple
                        ? context.colores.exito.texto
                        : context.colores.peligro.texto,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CRM declaró ${declaradas.toStringAsFixed(0)} hs',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: requeridas == 0
                        ? 0.0
                        : (completadas / requeridas).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: context.colorScheme.surfaceContainer,
                    color: !requerida
                        ? context.colorScheme.outlineVariant
                        : cumple
                        ? context.colores.exito.texto
                        : context.colores.advertencia.texto,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Muestra Moodle y CRM lado a lado; en pantallas angostas los apila.
  Widget _buildColumnasCursos(
    BuildContext context,
    DetalleEmpleadoViewModel detalle,
  ) {
    final horasCrm = detalle.cargasCrm.fold<double>(
      0,
      (total, item) => total + item.carga.horasTotales,
    );
    // Horas del catálogo de los cursos Moodle finalizados en el período.
    final horasMoodle = detalle.certificacionesMoodle
        .where((item) => item.finalizoCurso)
        .fold<double>(
          0,
          (total, item) =>
              total +
              (detalle.cursoPorNombre(item.cursoNombre)?.cargaHorariaHs ?? 0),
        );
    final columnaMoodle = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEncabezadoColumna(
          context,
          icono: Icons.school_outlined,
          titulo: 'Moodle (LMS)',
          detalle: '${_formatearHoras(horasMoodle)} hs',
        ),
        const SizedBox(height: 8),
        _buildColumnaMoodle(context, detalle),
      ],
    );
    final columnaCrm = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEncabezadoColumna(
          context,
          icono: Icons.schedule_outlined,
          titulo: 'CRM (horas declaradas)',
          detalle: '${_formatearHoras(horasCrm)} hs',
        ),
        const SizedBox(height: 8),
        _buildTablaCursadas(
          context,
          detalle.cargasCrm,
          detalle.cursosFinalizados,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [columnaMoodle, const SizedBox(height: 24), columnaCrm],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: columnaMoodle),
            const SizedBox(width: 16),
            Expanded(child: columnaCrm),
          ],
        );
      },
    );
  }

  Widget _buildEncabezadoColumna(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String detalle,
  }) {
    final cs = context.colorScheme;
    return Row(
      children: [
        Icon(icono, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        Text(
          detalle,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildEstadoVacio(BuildContext context, String mensaje) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: context.panel(),
      child: Center(
        child: Text(
          mensaje,
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildColumnaMoodle(
    BuildContext context,
    DetalleEmpleadoViewModel detalle,
  ) {
    if (detalle.certificacionesMoodle.isEmpty) {
      return _buildEstadoVacio(context, 'Sin certificaciones en el período.');
    }

    return Column(
      children: detalle.certificacionesMoodle.map((certificacion) {
        final curso = detalle.cursoPorNombre(certificacion.cursoNombre);
        return _CertificacionMoodleCard(
          certificacion: certificacion,
          nombreCurso: curso?.nombre ?? certificacion.cursoNombre,
          infoCurso: curso == null
              ? 'Curso no encontrado en el catálogo'
              : '${curso.clasificacion.label} · ${_formatearHoras(curso.cargaHorariaHs)} hs',
          fechaTexto: _formatearFecha(certificacion.fechaFinalizacion!),
        );
      }).toList(),
    );
  }

  Widget _buildTablaCursadas(
    BuildContext context,
    List<CargaDeHorasCRMViewModel> cursadas,
    Set<String> cursosFinalizados,
  ) {
    if (cursadas.isEmpty) {
      return _buildEstadoVacio(context, 'Sin cargas CRM en el período.');
    }
    final cs = context.colorScheme;
    final colores = context.colores;

    final grupos = <String, List<CargaDeHorasCRMViewModel>>{};
    for (final cursada in cursadas) {
      final cursoId = cursada.curso?.id.trim() ?? '';
      final nombreCurso = cursada.curso?.nombre ?? cursada.cursada.cursoNombre;
      final clave = cursoId.isNotEmpty
          ? 'id:$cursoId'
          : 'nombre:${nombreCurso.trim().toLowerCase()}';
      grupos.putIfAbsent(clave, () => []).add(cursada);
    }

    final cursosAgrupados = grupos.entries.toList()
      ..sort((a, b) => _nombreCurso(a.value).compareTo(_nombreCurso(b.value)));

    return Column(
      children: cursosAgrupados.map((grupo) {
        final registros = grupo.value
          ..sort((a, b) => b.cursada.fecha.compareTo(a.cursada.fecha));
        final primeraCursada = registros.first;
        final nombreCurso = _nombreCurso(registros);
        final cursoFinalizado = cursosFinalizados.contains(
          CumplimientoService.normalizarNombreCurso(nombreCurso),
        );
        final horasDeclaradas = registros.fold<double>(
          0,
          (total, item) => total + item.cursada.horasTotales,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: context.panel(radio: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ExpansionTile(
              key: PageStorageKey<String>('curso-${grupo.key}'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.menu_book_outlined,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      nombreCurso,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (cursoFinalizado) ...[
                    const SizedBox(width: 8),
                    EtiquetaColor(texto: 'Finalizado', colores: colores.exito),
                  ],
                ],
              ),
              subtitle: Text(
                '${primeraCursada.curso?.clasificacion.label ?? 'Tipo sin especificar'} · '
                '${registros.length} ${registros.length == 1 ? 'registro' : 'registros'} · '
                '${_formatearHoras(horasDeclaradas)} hs declaradas',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              children: [
                const Divider(height: 1),
                ...registros.map((registro) {
                  final fechaTexto = _formatearFecha(registro.cursada.fecha);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fechaTexto,
                            style: TextStyle(
                              fontSize: 13,
                              color: colores.textoIntermedio,
                            ),
                          ),
                        ),
                        if (registro.cursada.esDictada) ...[
                          EtiquetaColor(
                            texto: 'Dictada',
                            colores: colores.dictado,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${_formatearHoras(registro.cursada.horasTotales)} hs',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _nombreCurso(List<CargaDeHorasCRMViewModel> cursadas) {
    final primera = cursadas.first;
    return primera.curso?.nombre ?? primera.cursada.cursoNombre;
  }

  String _formatearHoras(double horas) => horas == horas.roundToDouble()
      ? horas.toStringAsFixed(0)
      : horas.toStringAsFixed(1);

  String _formatearFecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/'
      '${fecha.year}';

  Widget _buildTablaDictados(
    BuildContext context,
    List<CursoDictadoViewModel> dictados,
  ) {
    if (dictados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: context.panel(),
        child: const Center(
          child: Text('No registra cursos dictados como instructor.'),
        ),
      );
    }

    return Container(
      decoration: context.panel(),
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          context.colorScheme.surfaceContainerLow,
        ),
        columns: const [
          DataColumn(
            label: Text(
              'Código',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Curso impartido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Área temática',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Horas sumadas al plan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: dictados.map((c) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  c.codigo,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(
                Text(
                  c.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(Text(c.area)),
              DataCell(
                Text(
                  '${_formatearHoras(c.horas)} hs',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.colores.dictado.texto,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DatoEmpleado extends StatelessWidget {
  final String label;
  final String value;

  const _DatoEmpleado({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: context
          .panel(radio: 6)
          .copyWith(color: context.colorScheme.surfaceContainerLow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CertificacionMoodleCard extends StatelessWidget {
  final CertificacionMoodle certificacion;
  final String nombreCurso;
  final String infoCurso;
  final String fechaTexto;

  const _CertificacionMoodleCard({
    required this.certificacion,
    required this.nombreCurso,
    required this.infoCurso,
    required this.fechaTexto,
  });

  @override
  Widget build(BuildContext context) {
    final finalizado = certificacion.finalizoCurso;
    final cs = context.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: context.panel(radio: 6),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombreCurso,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    EtiquetaColor(
                      texto: finalizado ? 'Finalizado' : 'En curso',
                      colores: finalizado
                          ? context.colores.exito
                          : context.colores.advertencia,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$infoCurso · ${finalizado ? 'Finalizó' : 'Fecha'} $fechaTexto',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
