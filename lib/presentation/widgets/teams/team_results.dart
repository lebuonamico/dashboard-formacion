import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_card.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:flutter/material.dart';

const _maxCardWidth = 410.0;
const _gridSpacing = 16.0;
const _rowsPerPage = 2;

class EquiposResults extends StatefulWidget {
  final List<EquipoGlobalViewModel> equipos;
  final int totalEquipos;
  final bool esAnual;

  const EquiposResults({
    super.key,
    required this.equipos,
    required this.totalEquipos,
    this.esAnual = false,
  });

  @override
  State<EquiposResults> createState() => _EquiposResultsState();
}

class _EquiposResultsState extends State<EquiposResults> {
  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant EquiposResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Leandro: llama a _mismosEquipos para reiniciar la página cuando cambian los resultados.
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
                // Leandro: llama a _CountBadge para mostrar cuántos equipos coinciden con los filtros.
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
            if (widget.equipos.isEmpty)
              // Leandro: llama a _EmptySearch para avisar que ningún equipo coincide con los filtros.
              const _EmptySearch()
            else ...[
              if (cantidadPaginas > 1) ...[
                // Leandro: llama a PaginacionResultados para recorrer las páginas de equipos.
                PaginacionResultados(
                  paginaActual: paginaSegura,
                  cantidadPaginas: cantidadPaginas,
                  desde: desde + 1,
                  hasta: hasta,
                  totalResultados: widget.equipos.length,
                  etiquetaResultados: 'equipos',
                  icono: Icons.view_module_outlined,
                  onPrevious: paginaSegura == 0
                      ? null
                      : () => setState(() => _paginaActual = paginaSegura - 1),
                  onNext: paginaSegura == cantidadPaginas - 1
                      ? null
                      : () => setState(() => _paginaActual = paginaSegura + 1),
                ),
                const SizedBox(height: 18),
              ],
              // Leandro: llama a _TeamsGrid para mostrar los equipos de la página actual.
              _TeamsGrid(equipos: equiposVisibles, esAnual: widget.esAnual),
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
          color: equiposBrand,
        ),
      ),
    );
  }
}

class _TeamsGrid extends StatelessWidget {
  final List<EquipoGlobalViewModel> equipos;
  final bool esAnual;

  const _TeamsGrid({required this.equipos, required this.esAnual});

  @override
  Widget build(BuildContext context) {
    // Leandro: llama a GridView.builder para distribuir las tarjetas de equipos.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardWidth,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
        mainAxisExtent: 252,
      ),
      itemCount: equipos.length,
      // Leandro: llama a EquipoCard para mostrar el resumen de cada equipo visible.
      itemBuilder: (context, index) =>
          EquipoCard(equipo: equipos[index], esAnual: esAnual),
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
