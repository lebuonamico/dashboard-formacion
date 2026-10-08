import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/empty_data_state.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/shared/seniority_chip.dart';
import 'package:app_finnegans/presentation/widgets/shared/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';

class CursadasScreen extends ConsumerWidget {
  const CursadasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursadasAsync = ref.watch(cursadasCompletasProvider);

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
                        'Carga de horas CRM',
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
                        const _BarraFiltrosCrm(),
                        const SizedBox(height: 20),
                        Expanded(
                          child: cursadasAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (err, _) =>
                                Center(child: Text('Error: $err')),
                            data: (lista) {
                              if (lista.isEmpty) {
                                final hayCargas =
                                    ref
                                        .watch(cargasDeHorasCRMProvider)
                                        .value
                                        ?.isNotEmpty ??
                                    false;
                                return SingleChildScrollView(
                                  child: hayCargas
                                      ? const EmptyDataState(
                                          icon: Icons.search_off_outlined,
                                          title:
                                              'Ninguna carga de horas coincide con los filtros.',
                                          message:
                                              'Probá con otra búsqueda, período o área.',
                                        )
                                      : const EmptyDataState(
                                          icon: Icons.schedule_outlined,
                                          title: 'No hay horas CRM cargadas.',
                                          message:
                                              'Importá el reporte de horas del CRM.',
                                        ),
                                );
                              }
                              return _TablaCargasPaginada(cargas: lista);
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

/// Buscador + Año, Mes y Área. Es stateful para poder vaciar el texto del
/// buscador desde "Limpiar filtros".
class _BarraFiltrosCrm extends ConsumerStatefulWidget {
  const _BarraFiltrosCrm();

  @override
  ConsumerState<_BarraFiltrosCrm> createState() => _BarraFiltrosCrmState();
}

class _BarraFiltrosCrmState extends ConsumerState<_BarraFiltrosCrm> {
  late final TextEditingController _busqueda;

  @override
  void initState() {
    super.initState();
    // Los filtros persisten al navegar: el texto arranca con la búsqueda vigente.
    _busqueda = TextEditingController(
      text: ref.read(busquedaCargaDeHorasProvider),
    );
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _limpiarFiltros() {
    _busqueda.clear();
    ref.read(busquedaCargaDeHorasProvider.notifier).state = '';
    ref.read(filtroAnioCargaProvider.notifier).state = null;
    ref.read(filtroMesCargaProvider.notifier).state = null;
    ref.read(filtroAreaCargaProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final busqueda = ref.watch(busquedaCargaDeHorasProvider);
    final anio = ref.watch(filtroAnioCargaProvider);
    final mes = ref.watch(filtroMesCargaProvider);
    final area = ref.watch(filtroAreaCargaProvider);
    final anios = ref.watch(aniosCargasDisponiblesProvider).value ?? const [];
    final areas = ref.watch(areasCargasDisponiblesProvider).value ?? const [];

    final hayFiltros =
        busqueda.isNotEmpty || anio != null || mes != null || area != null;

    final selectorMes = _Desplegable<int?>(
      value: anio == null ? null : mes,
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos los meses'),
        ),
        for (var m = 1; m <= 12; m++)
          DropdownMenuItem<int?>(value: m, child: Text(nombreMes(m))),
      ],
      // Sin año elegido el mes no filtra: queda deshabilitado.
      onChanged: anio == null
          ? null
          : (val) => ref.read(filtroMesCargaProvider.notifier).state = val,
    );

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
                  ref.read(busquedaCargaDeHorasProvider.notifier).state = val,
              decoration: const InputDecoration(
                hintText: 'Buscar por colaborador, legajo o curso...',
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
          _Desplegable<int?>(
            value: anio,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todos los años'),
              ),
              // Si el año elegido ya no tiene cargas, se mantiene visible para
              // que el desplegable no quede con un valor inexistente.
              for (final a in {...anios, ?anio})
                DropdownMenuItem<int?>(value: a, child: Text('$a')),
            ],
            onChanged: (val) {
              ref.read(filtroAnioCargaProvider.notifier).state = val;
              if (val == null) {
                ref.read(filtroMesCargaProvider.notifier).state = null;
              }
            },
          ),
          const SizedBox(width: 12),
          if (anio == null)
            Tooltip(
              message: 'Elegí un año para filtrar por mes',
              child: selectorMes,
            )
          else
            selectorMes,
          const SizedBox(width: 12),
          _Desplegable<String?>(
            value: area,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las áreas'),
              ),
              for (final a in {...areas, ?area})
                DropdownMenuItem<String?>(value: a, child: Text(a)),
            ],
            onChanged: (val) =>
                ref.read(filtroAreaCargaProvider.notifier).state = val,
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

/// Gris de los datos secundarios (encabezados, legajo, equipo e ID).
const _grisSuave = Color(0xFF64748B);
const _tinta = Color(0xFF0F172A);
const _ambar = Color(0xFFD97706);

/// Encabezados en gris y chicos, igual que Certificaciones LMS.
const _estiloEncabezado = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: _grisSuave,
);

/// Tabla de cargas de horas, de a una página por vez y a todo el ancho.
class _TablaCargasPaginada extends StatefulWidget {
  final List<CursadaViewModel> cargas;

  const _TablaCargasPaginada({required this.cargas});

  @override
  State<_TablaCargasPaginada> createState() => _TablaCargasPaginadaState();
}

class _TablaCargasPaginadaState extends State<_TablaCargasPaginada> {
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
  void didUpdateWidget(covariant _TablaCargasPaginada oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar un filtro o la búsqueda, volver a la primera página.
    if (oldWidget.cargas != widget.cargas) {
      _paginaActual = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.cargas.length;

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
        final visibles = widget.cargas.sublist(inicio, fin);

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
                etiquetaResultados: 'registros',
                icono: Icons.schedule_outlined,
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

  Widget _tabla(List<CursadaViewModel> visibles) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.transparent),
      horizontalMargin: 0,
      columnSpacing: 24,
      headingRowHeight: _altoEncabezado,
      dataRowMinHeight: _altoFila,
      dataRowMaxHeight: _altoFila,
      dividerThickness: 1,
      // Proporciones del ancho: el curso y el colaborador son lo que más se
      // lee, la fecha y el ID son datos cortos.
      columns: const [
        DataColumn(
          columnWidth: FlexColumnWidth(1.2),
          label: Text('Fecha', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(3),
          label: Text('Colaborador', style: _estiloEncabezado),
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
          columnWidth: FlexColumnWidth(3.5),
          label: Text('Curso', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.5),
          label: Text('Horas CRM', style: _estiloEncabezado),
        ),
        DataColumn(
          columnWidth: FlexColumnWidth(1.3),
          label: Text('ID registro', style: _estiloEncabezado),
        ),
      ],
      rows: [
        for (final vm in visibles)
          DataRow(
            cells: [
              DataCell(
                Text(
                  _formatFecha(vm.cursada.fecha),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              DataCell(_celdaColaborador(vm)),
              DataCell(_celdaAreaEquipo(vm)),
              DataCell(
                vm.empleado == null
                    ? const Text('-', style: TextStyle(color: _grisSuave))
                    : SeniorityChip(seniority: vm.empleado!.seniority),
              ),
              DataCell(_celdaCurso(vm)),
              DataCell(_celdaHoras(vm)),
              DataCell(
                Text(
                  vm.cursada.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _grisSuave),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _celdaColaborador(CursadaViewModel vm) {
    final emp = vm.empleado;
    final legajo = vm.cursada.empleadoLegajo;

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
        Expanded(
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
      ],
    );
  }

  Widget _celdaAreaEquipo(CursadaViewModel vm) {
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

  Widget _celdaCurso(CursadaViewModel vm) {
    final nombre = vm.curso?.nombre ?? vm.cursada.cursoNombre;

    // El nombre se corta con puntos suspensivos; el tooltip muestra el nombre
    // completo.
    return Tooltip(
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
    );
  }

  Widget _celdaHoras(CursadaViewModel vm) {
    final carga = vm.cursada;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${carga.horasTotales.toStringAsFixed(2)} hs${carga.esDictada ? ' (dictadas)' : ' (tomadas)'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF047857),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
