import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/kpi_grid.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/shared/tipo_curso_chip.dart';
import 'package:app_finnegans/presentation/widgets/shared/user_avatar.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';

const _avisoCursoFueraDeCatalogo =
    'El curso no está en el catálogo: esta finalización no acredita horas.';
const _avisoLegajoFueraDeNomina =
    'El legajo no está en la nómina: no suma al cumplimiento de ningún equipo.';

class CertificacionScreen extends ConsumerWidget {
  const CertificacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completasAsync = ref.watch(certificacionesCompletasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                // TopBar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Certificaciones LMS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      UserAvatar(),
                    ],
                  ),
                ),

                // Contenido
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: completasAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                        child: Text(
                          'No se pudieron cargar las certificaciones LMS: $error',
                        ),
                      ),
                      data: (todas) {
                        if (todas.isEmpty) {
                          return const SingleChildScrollView(
                            child: EmptyDataState(
                              icon: Icons.menu_book_outlined,
                              title: 'No hay certificaciones LMS cargadas.',
                              message:
                                  'Importá el Excel de finalizaciones del LMS.',
                            ),
                          );
                        }

                        final filtradas =
                            ref.watch(certificacionesFiltradasProvider).value ??
                            const <CertificacionViewModel>[];
                        final totalNomina =
                            ref.watch(empleadosProvider).value?.length ?? 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KpiGrid(items: _kpis(todas, totalNomina)),
                            const SizedBox(height: 20),
                            _buildFilterBar(ref),
                            const SizedBox(height: 20),
                            Expanded(
                              child: filtradas.isEmpty
                                  ? const SingleChildScrollView(
                                      child: EmptyDataState(
                                        icon: Icons.search_off_outlined,
                                        title:
                                            'Ninguna certificación coincide con los filtros.',
                                        message:
                                            'Probá con otra búsqueda o estado.',
                                      ),
                                    )
                                  : _TablaCertificacionesPaginada(
                                      certificaciones: filtradas,
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Los KPIs resumen todo lo importado, no lo que dejan ver los filtros.
  List<KpiData> _kpis(List<CertificacionViewModel> todas, int totalNomina) {
    final total = todas.length;
    final finalizadas = todas
        .where((vm) => vm.certificacion.finalizoCurso)
        .length;
    final pendientes = total - finalizadas;
    final fueraDelCalculo = todas.where((vm) => vm.fueraDelCalculo).length;
    final colaboradoresCertificados = {
      for (final vm in todas)
        if (vm.certificacion.finalizoCurso && !vm.legajoFueraDeNomina)
          vm.certificacion.legajo,
    }.length;
    final porcentajeFinalizadas = total == 0 ? 0 : finalizadas / total * 100;

    return [
      KpiData(
        title: 'Registros',
        value: '$total',
        detail: fueraDelCalculo == 0
            ? 'todos cruzan con nómina y catálogo'
            : '$fueraDelCalculo fuera del cálculo',
        help:
            'Certificaciones importadas del LMS. Las que tienen un curso fuera '
            'del catálogo o un legajo fuera de la nómina no acreditan horas.',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF0D53C3),
      ),
      KpiData(
        title: 'Finalizadas',
        value: '$finalizadas',
        detail: '${porcentajeFinalizadas.toStringAsFixed(0)}% del total',
        icon: Icons.task_alt,
        color: const Color(0xFF16A34A),
      ),
      KpiData(
        title: 'Pendientes',
        value: '$pendientes',
        detail: 'sin finalización en el LMS',
        icon: Icons.pending_actions_outlined,
        color: const Color(0xFFD97706),
      ),
      KpiData(
        title: 'Colaboradores certificados',
        value: '$colaboradoresCertificados',
        detail: 'de $totalNomina en la nómina',
        help: 'Colaboradores de la nómina con al menos un curso finalizado.',
        icon: Icons.workspace_premium_outlined,
        color: const Color(0xFF7E22CE),
      ),
    ];
  }

  Widget _buildFilterBar(WidgetRef ref) {
    final estadoSeleccionado = ref.watch(filtroEstadoCertificacionProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) =>
                  ref.read(busquedaCertificacionMoodleProvider.notifier).state =
                      val,
              decoration: const InputDecoration(
                hintText:
                    'Buscar por colaborador, legajo, curso, área o equipo...',
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButton<bool?>(
                value: estadoSeleccionado,
                hint: const Text('Todos los estados'),
                items: const [
                  DropdownMenuItem<bool?>(
                    value: null,
                    child: Text('Todos los estados'),
                  ),
                  DropdownMenuItem<bool?>(
                    value: true,
                    child: Text('Finalizado'),
                  ),
                  DropdownMenuItem<bool?>(
                    value: false,
                    child: Text('Pendiente'),
                  ),
                ],
                onChanged: (val) =>
                    ref.read(filtroEstadoCertificacionProvider.notifier).state =
                        val,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gris de los datos secundarios (encabezados, legajo, área y equipo).
const _grisSuave = Color(0xFF64748B);
const _tinta = Color(0xFF0F172A);
const _ambar = Color(0xFFD97706);

/// Encabezados en gris y chicos, igual que el catálogo de cursos.
const _estiloEncabezado = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: _grisSuave,
);

/// Tabla de certificaciones, de a una página por vez y a todo el ancho.
class _TablaCertificacionesPaginada extends StatefulWidget {
  final List<CertificacionViewModel> certificaciones;

  const _TablaCertificacionesPaginada({required this.certificaciones});

  @override
  State<_TablaCertificacionesPaginada> createState() =>
      _TablaCertificacionesPaginadaState();
}

class _TablaCertificacionesPaginadaState
    extends State<_TablaCertificacionesPaginada> {
  // Filas de dos líneas: colaborador + legajo y área + equipo.
  static const _altoFila = 56.0;
  static const _altoEncabezado = 44.0;
  static const _altoPaginador = 60.0;
  static const _separacion = 12.0;

  /// Debajo de este ancho las columnas se aprietan demasiado: aparece el
  /// scroll horizontal en lugar de cortar todos los textos.
  static const _anchoMinimo = 1000.0;

  /// Mínimo razonable si la ventana queda muy baja.
  static const _minimoPorPagina = 5;

  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant _TablaCertificacionesPaginada oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar el filtro o la búsqueda, volver a la primera página.
    if (oldWidget.certificaciones != widget.certificaciones) {
      _paginaActual = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.certificaciones.length;

        // Cuántas filas entran en el alto disponible, para que la tabla llene
        // la página sin dejar un hueco antes del paginador.
        final altoParaTabla =
            constraints.maxHeight - _altoPaginador - _separacion;
        final porPagina = ((altoParaTabla - _altoEncabezado) / _altoFila)
            .floor()
            .clamp(
              _minimoPorPagina,
              total < _minimoPorPagina ? _minimoPorPagina : total,
            );

        final totalPaginas = total == 0
            ? 1
            : (total + porPagina - 1) ~/ porPagina;
        final paginaSegura = _paginaActual.clamp(0, totalPaginas - 1);
        final inicio = paginaSegura * porPagina;
        final finCalculado = inicio + porPagina;
        final fin = finCalculado > total ? total : finCalculado;
        final visibles = widget.certificaciones.sublist(inicio, fin);

        // Ancho fijo (no un mínimo): las columnas flex necesitan un ancho
        // acotado para repartirse, si no colapsan dentro del scroll.
        final ancho = constraints.maxWidth < _anchoMinimo
            ? _anchoMinimo
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: ancho,
                  // Red de seguridad por si algo no entra.
                  child: SingleChildScrollView(child: _tabla(visibles)),
                ),
              ),
            ),
            if (totalPaginas > 1) ...[
              const SizedBox(height: _separacion),
              PaginacionResultados(
                paginaActual: paginaSegura,
                cantidadPaginas: totalPaginas,
                desde: inicio + 1,
                hasta: fin,
                totalResultados: total,
                etiquetaResultados: 'certificaciones',
                icono: Icons.workspace_premium_outlined,
                onPrevious: paginaSegura > 0
                    ? () => setState(() => _paginaActual = paginaSegura - 1)
                    : null,
                onNext: paginaSegura < totalPaginas - 1
                    ? () => setState(() => _paginaActual = paginaSegura + 1)
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _tabla(List<CertificacionViewModel> visibles) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.transparent),
      horizontalMargin: 0,
      columnSpacing: 24,
      headingRowHeight: _altoEncabezado,
      dataRowMinHeight: _altoFila,
      dataRowMaxHeight: _altoFila,
      dividerThickness: 1,
      // Proporciones del ancho: el curso y el colaborador son lo que más se
      // lee, la carga horaria y la fecha son datos cortos.
      columns: const [
        DataColumn(
          columnWidth: FlexColumnWidth(3),
          label: Text('Colaborador', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(2.5),
          label: Text('Área / Equipo', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(3.5),
          label: Text('Curso', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(2),
          label: Text('Tipo', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.2),
          label: Text('Carga horaria', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.5),
          label: Text('Finalización', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.5),
          label: Text('Estado', style: _estiloEncabezado),
        ),
      ],
      rows: [
        for (final vm in visibles)
          DataRow(
            cells: [
              DataCell(_celdaColaborador(vm)),
              DataCell(_celdaAreaEquipo(vm)),
              DataCell(_celdaCurso(vm)),
              DataCell(
                vm.curso == null
                    ? const Text('-', style: TextStyle(color: _grisSuave))
                    : TipoCursoChip(tipo: vm.curso!.tipo),
              ),
              DataCell(
                Text(
                  vm.curso == null
                      ? '-'
                      : '${vm.curso!.cargaHorariaHs.toStringAsFixed(0)} hs',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: vm.curso == null ? _grisSuave : _tinta,
                  ),
                ),
              ),
              DataCell(_celdaFecha(vm.certificacion.fechaFinalizacion)),
              DataCell(_EstadoChip(finalizado: vm.certificacion.finalizoCurso)),
            ],
          ),
      ],
    );
  }

  Widget _celdaColaborador(CertificacionViewModel vm) {
    final emp = vm.empleado;
    final legajo = vm.certificacion.legajo;

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Text(
            emp == null || emp.nombre.isEmpty
                ? '?'
                : emp.nombre.substring(0, 1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _tinta,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Flexible y no Expanded: el aviso queda pegado al texto, igual que en
        // la columna Curso, en lugar de irse al borde de la columna.
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                emp == null
                    ? 'Legajo $legajo'
                    : '${emp.nombre} ${emp.apellido}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _tinta,
                ),
              ),
              Text(
                emp == null ? 'Fuera de la nómina' : 'Legajo $legajo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: emp == null ? _ambar : _grisSuave,
                ),
              ),
            ],
          ),
        ),
        if (vm.legajoFueraDeNomina) const _Aviso(_avisoLegajoFueraDeNomina),
      ],
    );
  }

  Widget _celdaAreaEquipo(CertificacionViewModel vm) {
    final emp = vm.empleado;
    if (emp == null) {
      return const Text('-', style: TextStyle(color: _grisSuave));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _mostrarDato(emp.area),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
        ),
        Text(
          _mostrarDato(emp.equipo),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: _grisSuave),
        ),
      ],
    );
  }

  Widget _celdaCurso(CertificacionViewModel vm) {
    final nombre = vm.curso?.nombre ?? vm.certificacion.cursoNombre;

    return Row(
      children: [
        Flexible(
          // El nombre se corta con puntos suspensivos; el tooltip muestra el
          // nombre completo.
          child: Tooltip(
            message: nombre,
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _tinta,
              ),
            ),
          ),
        ),
        if (vm.cursoFueraDeCatalogo) const _Aviso(_avisoCursoFueraDeCatalogo),
      ],
    );
  }

  Widget _celdaFecha(DateTime? fecha) {
    return Text(
      fecha == null ? '—' : _formatFecha(fecha),
      style: TextStyle(
        fontSize: 13,
        color: fecha == null
            ? const Color(0xFF94A3B8)
            : const Color(0xFF334155),
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  String _mostrarDato(String valor) => valor.trim().isEmpty ? '-' : valor;
}

/// Ícono ámbar que avisa por qué una certificación no entra al cumplimiento.
class _Aviso extends StatelessWidget {
  final String mensaje;

  const _Aviso(this.mensaje);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: mensaje,
        child: const Icon(Icons.warning_amber_rounded, size: 18, color: _ambar),
      ),
    );
  }
}

/// Estado con los colores del semáforo: verde finalizado, ámbar pendiente.
class _EstadoChip extends StatelessWidget {
  final bool finalizado;

  const _EstadoChip({required this.finalizado});

  @override
  Widget build(BuildContext context) {
    final texto = finalizado ? const Color(0xFF16A34A) : _ambar;
    final fondo = finalizado
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF3C7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        finalizado ? 'Finalizado' : 'Pendiente',
        style: TextStyle(
          color: texto,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
