import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipo_card.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

const _maxCardWidth = 410.0;
const _gridSpacing = 16.0;
const _rowsPerPage = 2;

/// Leandro: Recibe los equipos filtrados y llama a EquipoCard por cada resultado.
class EquiposResults extends StatefulWidget {
  final List<EquipoGlobalViewModel> equipos;
  final int totalEquipos;

  const EquiposResults({
    super.key,
    required this.equipos,
    required this.totalEquipos,
  });

  @override
  State<EquiposResults> createState() => _EquiposResultsState();
}

class _EquiposResultsState extends State<EquiposResults> {
  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant EquiposResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Leandro: Si se recargan los datos, el listado vuelve a una página válida.
    if (!_mismosEquipos(oldWidget.equipos, widget.equipos)) {
      _paginaActual = 0;
    }
  }

  bool _mismosEquipos(
    List<EquipoGlobalViewModel> anteriores,
    List<EquipoGlobalViewModel> actuales,
  ) {
    if (anteriores.length != actuales.length) return false;
    for (var index = 0; index < actuales.length; index++) {
      final anterior = anteriores[index];
      final actual = actuales[index];
      if (anterior.id != actual.id ||
          anterior.horasRealizadas != actual.horasRealizadas ||
          anterior.horasObjetivo != actual.horasObjetivo) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leandro: La cantidad por página se adapta al ancho y completa dos filas.
        final columnasCalculadas =
            (constraints.maxWidth / (_maxCardWidth + _gridSpacing)).ceil();
        final columnas = columnasCalculadas < 1 ? 1 : columnasCalculadas;
        final itemsPorPagina = columnas * _rowsPerPage;
        final cantidadPaginas = (widget.equipos.length / itemsPorPagina).ceil();
        final paginaSegura = cantidadPaginas == 0
            ? 0
            : _paginaActual.clamp(0, cantidadPaginas - 1);
        final desde = paginaSegura * itemsPorPagina;
        final hasta = (desde + itemsPorPagina).clamp(0, widget.equipos.length);
        final equiposVisibles = widget.equipos.sublist(desde, hasta);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Equipos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: equiposInk,
                  ),
                ),
                const SizedBox(width: 8),
                _CountBadge(count: widget.equipos.length),
                const Spacer(),
                Text(
                  widget.equipos.length == widget.totalEquipos
                      ? '${widget.totalEquipos} equipos en el período'
                      : '${widget.equipos.length} de ${widget.totalEquipos} equipos',
                  style: const TextStyle(fontSize: 13, color: equiposMuted),
                ),
              ],
            ),
            const SizedBox(height: 13),
            // Leandro: Sin coincidencias cambia sólo esta sección; los KPI siguen visibles.
            if (widget.equipos.isEmpty)
              const _EmptySearch()
            else ...[
              if (cantidadPaginas > 1) ...[
                _PaginationControls(
                  paginaActual: paginaSegura,
                  cantidadPaginas: cantidadPaginas,
                  desde: desde + 1,
                  hasta: hasta,
                  totalResultados: widget.equipos.length,
                  onPrevious: paginaSegura == 0
                      ? null
                      : () => setState(() => _paginaActual = paginaSegura - 1),
                  onNext: paginaSegura == cantidadPaginas - 1
                      ? null
                      : () => setState(() => _paginaActual = paginaSegura + 1),
                ),
                const SizedBox(height: 18),
              ],
              _TeamsGrid(equipos: equiposVisibles),
            ],
          ],
        );
      },
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int paginaActual;
  final int cantidadPaginas;
  final int desde;
  final int hasta;
  final int totalResultados;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationControls({
    required this.paginaActual,
    required this.cantidadPaginas,
    required this.desde,
    required this.hasta,
    required this.totalResultados,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: equiposBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 20,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.view_module_outlined,
                size: 20,
                color: equiposBrand,
              ),
              const SizedBox(width: 9),
              Text(
                'Mostrando $desde-$hasta de $totalResultados equipos',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: equiposInk,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Página anterior',
              ),
              const SizedBox(width: 12),
              Text(
                'Página ${paginaActual + 1} de $cantidadPaginas',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: equiposInk,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Página siguiente',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Leandro: Contador de equipos visibles después de aplicar filtros.
class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: equiposBrand,
        ),
      ),
    );
  }
}

// Leandro: Convierte la lista filtrada en una grilla de EquipoCard.
class _TeamsGrid extends StatelessWidget {
  final List<EquipoGlobalViewModel> equipos;

  const _TeamsGrid({required this.equipos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Leandro: El desplazamiento lo maneja el ListView principal de EquiposScreen.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardWidth,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
        mainAxisExtent: 252,
      ),
      itemCount: equipos.length,
      itemBuilder: (context, index) => EquipoCard(equipo: equipos[index]),
    );
  }
}

// Leandro: Se muestra cuando los filtros no encuentran coincidencias.
class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: equiposPanelDecoration(),
      child: const Column(
        children: [
          Icon(Icons.search_off_outlined, size: 30, color: equiposMuted),
          SizedBox(height: 10),
          Text(
            'No encontramos equipos con esos filtros.',
            style: TextStyle(fontWeight: FontWeight.w600, color: equiposInk),
          ),
          SizedBox(height: 4),
          Text(
            'Probá con otra búsqueda, área o estado.',
            style: TextStyle(fontSize: 13, color: equiposMuted),
          ),
        ],
      ),
    );
  }
}
