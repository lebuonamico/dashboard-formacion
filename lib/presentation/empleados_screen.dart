import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:app_finnegans/presentation/widgets/shared/category_hours_progress.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/shared/seniority_chip.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';

class EmpleadosScreen extends ConsumerWidget {
  const EmpleadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empleadosFiltrados = ref.watch(empleadosFiltradosProvider);
    final cumplimientos = ref.watch(cumplimientoGlobalProvider);

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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Directorio de empleados',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const UserAvatar(),
                    ],
                  ),
                ),

                // Contenido
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _BarraFiltrosEmpleados(),
                        const SizedBox(height: 20),
                        Expanded(
                          child: empleadosFiltrados.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (err, _) =>
                                Center(child: Text('Error: $err')),
                            data: (empleados) {
                              if (empleados.isEmpty) {
                                final hayNomina =
                                    ref
                                        .watch(empleadosProvider)
                                        .value
                                        ?.isNotEmpty ??
                                    false;
                                return SingleChildScrollView(
                                  child: hayNomina
                                      ? const EmptyDataState(
                                          icon: Icons.search_off_outlined,
                                          title:
                                              'Ningún empleado coincide con los filtros.',
                                          message:
                                              'Probá con otra búsqueda o seniority.',
                                        )
                                      : const EmptyDataState(
                                          icon: Icons.people_outline,
                                          title: 'No hay empleados cargados.',
                                          message:
                                              'Importá la nómina para ver el directorio.',
                                        ),
                                );
                              }
                              return cumplimientos.when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (_, _) => _TablaEmpleadosPaginada(
                                  empleados: empleados,
                                  cumplimientoPorLegajo: const {},
                                ),
                                data: (items) {
                                  final porLegajo = {
                                    for (final item in items)
                                      item.empleado.legajo: item,
                                  };
                                  return _TablaEmpleadosPaginada(
                                    empleados: empleados,
                                    cumplimientoPorLegajo: porLegajo,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
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
}

/// Buscador + Seniority. Es stateful para poder vaciar el texto del buscador
/// desde "Limpiar filtros".
class _BarraFiltrosEmpleados extends ConsumerStatefulWidget {
  const _BarraFiltrosEmpleados();

  @override
  ConsumerState<_BarraFiltrosEmpleados> createState() =>
      _BarraFiltrosEmpleadosState();
}

class _BarraFiltrosEmpleadosState
    extends ConsumerState<_BarraFiltrosEmpleados> {
  late final TextEditingController _busqueda;

  @override
  void initState() {
    super.initState();
    // Los filtros persisten al navegar: el texto arranca con la búsqueda vigente.
    _busqueda = TextEditingController(
      text: ref.read(busquedaEmpleadoProvider),
    );
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _limpiarFiltros() {
    _busqueda.clear();
    ref.read(busquedaEmpleadoProvider.notifier).state = '';
    ref.read(filtroSeniorityProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final busqueda = ref.watch(busquedaEmpleadoProvider);
    final seniority = ref.watch(filtroSeniorityProvider);

    final hayFiltros = busqueda.isNotEmpty || seniority != null;

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
              controller: _busqueda,
              onChanged: (val) =>
                  ref.read(busquedaEmpleadoProvider.notifier).state = val,
              decoration: const InputDecoration(
                hintText:
                    'Buscar por nombre, legajo, área, equipo o gerente...',
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
          _Desplegable<Seniority?>(
            value: seniority,
            items: [
              const DropdownMenuItem<Seniority?>(
                value: null,
                child: Text('Todos los seniorities'),
              ),
              for (final s in Seniority.values)
                DropdownMenuItem<Seniority?>(value: s, child: Text(s.label)),
            ],
            onChanged: (val) =>
                ref.read(filtroSeniorityProvider.notifier).state = val,
          ),
          if (hayFiltros) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Limpiar filtros'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D53C3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Desplegable con el borde de los filtros del resto de las pantallas.
class _Desplegable<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _Desplegable({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: onChanged == null ? const Color(0xFFF8FAFC) : null,
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Gris de los datos secundarios (encabezados, mail y equipo).
const _grisSuave = Color(0xFF64748B);
const _tinta = Color(0xFF0F172A);

/// Encabezados en gris y chicos, igual que Carga de horas CRM.
const _estiloEncabezado = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: _grisSuave,
);

/// Tabla del directorio, de a una página por vez y a todo el ancho.
class _TablaEmpleadosPaginada extends StatefulWidget {
  final List<Empleado> empleados;
  final Map<String, CumplimientoEmpleado> cumplimientoPorLegajo;

  const _TablaEmpleadosPaginada({
    required this.empleados,
    required this.cumplimientoPorLegajo,
  });

  @override
  State<_TablaEmpleadosPaginada> createState() =>
      _TablaEmpleadosPaginadaState();
}

class _TablaEmpleadosPaginadaState extends State<_TablaEmpleadosPaginada> {
  // Filas de dos líneas: nombre + mail, área + equipo y las fichas de
  // progreso en dos renglones.
  static const _altoFila = 56.0;
  static const _altoEncabezado = 44.0;
  static const _altoPaginador = 60.0;
  static const _separacion = 12.0;

  /// Debajo de este ancho las columnas se aprietan demasiado: aparece el
  /// scroll horizontal en lugar de cortar todos los textos. Es mayor que en
  /// el CRM porque la columna de progreso tiene ancho fijo.
  static const _anchoMinimo = 1100.0;

  /// Las fichas de [ProgresoHorasPorCategoria] miden 256 px fijos; la columna
  /// suma el espacio entre columnas para que no desborden.
  static const _anchoProgreso = 256.0 + 24.0;

  /// Mínimo razonable si la ventana queda muy baja.
  static const _minimoPorPagina = 5;

  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant _TablaEmpleadosPaginada oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar el filtro o la búsqueda, volver a la primera página.
    if (oldWidget.empleados != widget.empleados) {
      _paginaActual = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.empleados.length;

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
        final visibles = widget.empleados.sublist(inicio, fin);

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
                etiquetaResultados: 'empleados',
                icono: Icons.people_outline,
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

  Widget _tabla(List<Empleado> visibles) {
    return DataTable(
      showCheckboxColumn: false,
      headingRowColor: WidgetStateProperty.all(Colors.transparent),
      horizontalMargin: 0,
      columnSpacing: 24,
      headingRowHeight: _altoEncabezado,
      dataRowMinHeight: _altoFila,
      dataRowMaxHeight: _altoFila,
      dividerThickness: 1,
      // Proporciones del ancho: el nombre y el área son lo que más se lee,
      // el legajo es un dato corto.
      columns: const [
        DataColumn(
          columnWidth: FlexColumnWidth(1),
          label: Text('Legajo', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(3),
          label: Text('Empleado', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(2.5),
          label: Text('Área / Equipo', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.6),
          label: Text('Seniority', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FixedColumnWidth(_anchoProgreso),
          label: Text('Progreso por categoría', style: _estiloEncabezado),
        ),
      ],
      rows: [
        for (final emp in visibles)
          DataRow(
            onSelectChanged: (_) => context.push('/empleados/${emp.legajo}'),
            cells: [
              DataCell(
                Text(
                  emp.legajo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              DataCell(_celdaEmpleado(emp)),
              DataCell(_celdaAreaEquipo(emp)),
              DataCell(SeniorityChip(seniority: emp.seniority)),
              DataCell(
                ProgresoHorasPorCategoria(
                  cumplimiento: widget.cumplimientoPorLegajo[emp.legajo],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _celdaEmpleado(Empleado emp) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFE2E8F0),
          child: Text(
            emp.nombre.isEmpty ? '?' : emp.nombre.substring(0, 1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _tinta,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${emp.nombre} ${emp.apellido}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _tinta,
                ),
              ),
              Text(
                _mostrarDato(emp.mail),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _grisSuave),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _celdaAreaEquipo(Empleado emp) {
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

  String _mostrarDato(String valor) => valor.trim().isEmpty ? '-' : valor;
}
