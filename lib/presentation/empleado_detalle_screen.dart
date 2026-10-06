import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/period_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/periodo_filter_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                // TopBar con botón Volver
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF0F172A),
                        ),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Perfil del colaborador',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido
                Expanded(
                  child: detalleAsync.when(
                    // Al cambiar el período mantiene los datos previos en pantalla.
                    skipLoadingOnReload: true,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                    data: (detalle) {
                      if (detalle == null) {
                        return const Center(
                          child: Text('Empleado no encontrado.'),
                        );
                      }

                      final emp = detalle.empleado;
                      final cump = detalle.cumplimiento;

                      return ListView(
                        padding: const EdgeInsets.all(24.0),
                        children: [
                          // Cabecera con datos del empleado
                          _buildHeaderEmpleado(emp, cump),
                          const SizedBox(height: 16),

                          // Filtro de período global
                          const PeriodoFilterPanel(),
                          const SizedBox(height: 24),

                          // Desglose de cumplimiento por categoría
                          Text(
                            'Desglose del plan de formación ($periodoTexto)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildGridCategorias(cump),
                          const SizedBox(height: 24),

                          // Cursos del período: Moodle y CRM
                          Text(
                            'Cursos del período ($periodoTexto)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildColumnasCursos(detalle),
                          const SizedBox(height: 24),

                          // Cursos Dictados (si aplica al seniority)
                          if ((cump.horasRequeridas[TipoCurso
                                          .dictadoCapacitaciones] ??
                                      0) >
                                  0 ||
                              detalle.cursosDictados.isNotEmpty) ...[
                            const Text(
                              'Cursos dictados como instructor',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTablaDictados(detalle.cursosDictados),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderEmpleado(Empleado emp, CumplimientoEmpleado cump) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF0D53C3),
            child: Text(
              emp.nombre.trim().isEmpty
                  ? '?'
                  : emp.nombre.trim().substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        emp.seniority.label,
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Área de ${emp.area} · Legajo: ${emp.legajo}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emp.mail,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cump.cumpleObjetivo
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${cump.totalHorasValidas.toStringAsFixed(0)} / ${cump.totalHorasRequeridas.toStringAsFixed(0)} hs LMS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cump.cumpleObjetivo
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cump.cumpleObjetivo ? 'Objetivo cumplido' : 'En progreso',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cump.cumpleObjetivo
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CRM declaró ${cump.totalHorasDeclaradas.toStringAsFixed(0)} hs',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mostrarDato(String valor) => valor.trim().isEmpty ? '-' : valor;

  Widget _buildGridCategorias(CumplimientoEmpleado cump) {
    return Row(
      children: TipoCurso.values.map((tipo) {
        final completadas = cump.horasValidas[tipo] ?? 0.0;
        final declaradas = cump.horasDeclaradas[tipo] ?? 0.0;
        final requeridas = cump.horasRequeridas[tipo] ?? 0.0;
        final requerida = requeridas > 0;
        final cumple = requerida && completadas >= requeridas;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tipo.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  requerida
                      ? '${completadas.toStringAsFixed(0)} / ${requeridas.toStringAsFixed(0)} hs LMS'
                      : 'No requerida',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: !requerida
                        ? const Color(0xFF64748B)
                        : cumple
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'CRM declaró ${declaradas.toStringAsFixed(0)} hs',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
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
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: !requerida
                        ? const Color(0xFFE2E8F0)
                        : cumple
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF59E0B),
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
  Widget _buildColumnasCursos(DetalleEmpleadoViewModel detalle) {
    final horasCrm = detalle.cargasCrm.fold<double>(
      0,
      (total, item) => total + item.carga.horasTotales,
    );
    final columnaMoodle = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEncabezadoColumna(
          icono: Icons.school_outlined,
          titulo: 'Moodle (LMS)',
          detalle:
              '${detalle.certificacionesMoodle.length} '
              '${detalle.certificacionesMoodle.length == 1 ? 'certificación' : 'certificaciones'}',
        ),
        const SizedBox(height: 8),
        _buildColumnaMoodle(detalle),
      ],
    );
    final columnaCrm = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEncabezadoColumna(
          icono: Icons.schedule_outlined,
          titulo: 'CRM (horas declaradas)',
          detalle: '${_formatearHoras(horasCrm)} hs',
        ),
        const SizedBox(height: 8),
        _buildTablaCursadas(detalle.cargasCrm, detalle.cursosFinalizados),
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

  Widget _buildEncabezadoColumna({
    required IconData icono,
    required String titulo,
    required String detalle,
  }) {
    return Row(
      children: [
        Icon(icono, size: 18, color: const Color(0xFF0D53C3)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Text(
          detalle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildEstadoVacio(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(mensaje, style: const TextStyle(color: Color(0xFF64748B))),
      ),
    );
  }

  Widget _buildColumnaMoodle(DetalleEmpleadoViewModel detalle) {
    if (detalle.certificacionesMoodle.isEmpty) {
      return _buildEstadoVacio('Sin certificaciones en el período.');
    }

    return Column(
      children: detalle.certificacionesMoodle.map((certificacion) {
        final curso = detalle.cursoPorNombre(certificacion.cursoNombre);
        return _CertificacionMoodleCard(
          certificacion: certificacion,
          nombreCurso: curso?.nombre ?? certificacion.cursoNombre,
          infoCurso: curso == null
              ? 'Curso no encontrado en el catálogo'
              : '${curso.tipo.label} · ${_formatearHoras(curso.cargaHorariaHs)} hs',
          fechaTexto: _formatearFecha(certificacion.fechaFinalizacion!),
        );
      }).toList(),
    );
  }

  Widget _buildTablaCursadas(
    List<CargaDeHorasCRMViewModel> cursadas,
    Set<String> cursosFinalizados,
  ) {
    if (cursadas.isEmpty) {
      return _buildEstadoVacio('Sin cargas CRM en el período.');
    }

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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ExpansionTile(
              key: PageStorageKey<String>('curso-${grupo.key}'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.menu_book_outlined,
                color: Color(0xFF64748B),
                size: 20,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      nombreCurso,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (cursoFinalizado) ...[
                    const SizedBox(width: 8),
                    const _Badge(
                      texto: 'Finalizado',
                      fondo: Color(0xFFDCFCE7),
                      color: Color(0xFF15803D),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '${primeraCursada.curso?.tipo.label ?? 'Tipo sin especificar'} · '
                '${registros.length} ${registros.length == 1 ? 'registro' : 'registros'} · '
                '${_formatearHoras(horasDeclaradas)} hs declaradas',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              children: [
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                ...registros.map((registro) {
                  final fechaTexto = _formatearFecha(registro.cursada.fecha);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fechaTexto,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (registro.cursada.esDictada) ...[
                          const _Badge(
                            texto: 'Dictada',
                            fondo: Color(0xFFFFEDD5),
                            color: Color(0xFFC2410C),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${_formatearHoras(registro.cursada.horasTotales)} hs',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
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

  Widget _buildTablaDictados(List<Curso> dictados) {
    if (dictados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No registra cursos dictados como instructor.'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
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
                Text(c.id, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              DataCell(
                Text(
                  c.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(Text(c.areaCurso)),
              DataCell(
                Text(
                  '${c.cargaHorariaHs.toStringAsFixed(0)} hs',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2410C),
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
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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

class _Badge extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color color;

  const _Badge({required this.texto, required this.fondo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            color: Color(0xFF64748B),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    finalizado
                        ? const _Badge(
                            texto: 'Finalizado',
                            fondo: Color(0xFFDCFCE7),
                            color: Color(0xFF15803D),
                          )
                        : const _Badge(
                            texto: 'En curso',
                            fondo: Color(0xFFFEF3C7),
                            color: Color(0xFFB45309),
                          ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$infoCurso · ${finalizado ? 'Finalizó' : 'Fecha'} $fechaTexto',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
