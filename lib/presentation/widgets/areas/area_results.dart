import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_card.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:flutter/material.dart';

const _maxCardWidth = 410.0;
const _gridSpacing = 16.0;
const _rowsPerPage = 2;

class AreasResults extends StatefulWidget {
  final List<AreaGlobalViewModel> areas;
  final int totalAreas;
  final bool esAnual;
  final String? origen;

  const AreasResults({
    super.key,
    required this.areas,
    required this.totalAreas,
    this.esAnual = false,
    this.origen,
  });

  @override
  State<AreasResults> createState() => _AreasResultsState();
}

class _AreasResultsState extends State<AreasResults> {
  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant AreasResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambian los resultados, volver a la primera página.
    if (!_mismasAreas(oldWidget.areas, widget.areas)) {
      _paginaActual = 0;
    }
  }

  bool _mismasAreas(
    List<AreaGlobalViewModel> anteriores,
    List<AreaGlobalViewModel> actuales,
  ) {
    if (anteriores.length != actuales.length) return false;
    for (var index = 0; index < actuales.length; index++) {
      final anterior = anteriores[index];
      final actual = actuales[index];
      if (anterior.nombre != actual.nombre ||
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
        final columnasCalculadas =
            (constraints.maxWidth / (_maxCardWidth + _gridSpacing)).ceil();
        final columnas = columnasCalculadas < 1 ? 1 : columnasCalculadas;
        final itemsPorPagina = columnas * _rowsPerPage;
        final cantidadPaginas = (widget.areas.length / itemsPorPagina).ceil();
        final paginaSegura = cantidadPaginas == 0
            ? 0
            : _paginaActual.clamp(0, cantidadPaginas - 1);
        final desde = paginaSegura * itemsPorPagina;
        final hasta = (desde + itemsPorPagina).clamp(0, widget.areas.length);
        final areasVisibles = widget.areas.sublist(desde, hasta);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Áreas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: areasInk,
                  ),
                ),
                const SizedBox(width: 8),
                _CountBadge(count: widget.areas.length),
                const Spacer(),
                Text(
                  widget.areas.length == widget.totalAreas
                      ? '${widget.totalAreas} áreas en el período'
                      : '${widget.areas.length} de ${widget.totalAreas} áreas',
                  style: const TextStyle(fontSize: 13, color: areasMuted),
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (widget.areas.isEmpty)
              const _EmptySearch()
            else ...[
              if (cantidadPaginas > 1) ...[
                PaginacionResultados(
                  paginaActual: paginaSegura,
                  cantidadPaginas: cantidadPaginas,
                  desde: desde + 1,
                  hasta: hasta,
                  totalResultados: widget.areas.length,
                  etiquetaResultados: 'áreas',
                  icono: Icons.apartment_outlined,
                  onPrevious: paginaSegura == 0
                      ? null
                      : () => setState(() => _paginaActual = paginaSegura - 1),
                  onNext: paginaSegura == cantidadPaginas - 1
                      ? null
                      : () => setState(() => _paginaActual = paginaSegura + 1),
                ),
                const SizedBox(height: 18),
              ],
              _AreasGrid(
                areas: areasVisibles,
                esAnual: widget.esAnual,
                origen: widget.origen,
              ),
            ],
          ],
        );
      },
    );
  }
}

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
          color: areasBrand,
        ),
      ),
    );
  }
}

class _AreasGrid extends StatelessWidget {
  final List<AreaGlobalViewModel> areas;
  final bool esAnual;
  final String? origen;

  const _AreasGrid({
    required this.areas,
    required this.esAnual,
    required this.origen,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardWidth,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
        mainAxisExtent: 252,
      ),
      itemCount: areas.length,
      itemBuilder: (context, index) =>
          AreaCard(area: areas[index], esAnual: esAnual, origen: origen),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: areasPanelDecoration(),
      child: const Column(
        children: [
          Icon(Icons.search_off_outlined, size: 30, color: areasMuted),
          SizedBox(height: 10),
          Text(
            'No hay áreas que coincidan con la búsqueda.',
            style: TextStyle(fontWeight: FontWeight.w600, color: areasInk),
          ),
          SizedBox(height: 4),
          Text(
            'Probá con otra búsqueda o estado.',
            style: TextStyle(fontSize: 13, color: areasMuted),
          ),
        ],
      ),
    );
  }
}
