import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';
import 'package:flutter/material.dart';

class EquiposFilters extends StatefulWidget {
  final List<String> areas;
  final String searchText;
  final String? selectedArea;
  final EstadoEquipo? selectedStatus;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onArea;
  final ValueChanged<EstadoEquipo?> onStatus;
  final VoidCallback onClear;

  const EquiposFilters({
    super.key,
    required this.areas,
    required this.searchText,
    required this.selectedArea,
    required this.selectedStatus,
    required this.hasActiveFilters,
    required this.onSearch,
    required this.onArea,
    required this.onStatus,
    required this.onClear,
  });

  @override
  State<EquiposFilters> createState() => _EquiposFiltersState();
}

class _EquiposFiltersState extends State<EquiposFilters> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchText);
  }

  @override
  void didUpdateWidget(covariant EquiposFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchText != _searchController.text) {
      _searchController.text = widget.searchText;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: equiposPanelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchField = TextField(
            controller: _searchController,
            // Leandro: llama a onSearch al escribir para actualizar la búsqueda de equipos.
            onChanged: widget.onSearch,
            decoration: _inputDecoration(
              'Buscar por equipo, área o líder',
              Icons.search,
            ),
          );
          final areaSeleccionadaValida =
              widget.areas.contains(widget.selectedArea)
              ? widget.selectedArea
              : null;
          final areaField = DropdownButtonFormField<String?>(
            key: ValueKey(areaSeleccionadaValida),
            initialValue: areaSeleccionadaValida,
            isExpanded: true,
            decoration: _inputDecoration(
              'Todas las áreas',
              Icons.apartment_outlined,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las áreas'),
              ),
              ...widget.areas.map(
                (area) => DropdownMenuItem<String?>(
                  value: area,
                  child: Text(area, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            // Leandro: llama a onArea para filtrar los equipos por el área seleccionada.
            onChanged: widget.onArea,
          );
          final statusField = DropdownButtonFormField<EstadoEquipo?>(
            initialValue: widget.selectedStatus,
            isExpanded: true,
            decoration: _inputDecoration(
              'Todos los estados',
              Icons.traffic_outlined,
            ),
            items: const [
              DropdownMenuItem<EstadoEquipo?>(
                value: null,
                child: Text('Todos los estados'),
              ),
              DropdownMenuItem<EstadoEquipo?>(
                value: EstadoEquipo.enObjetivo,
                child: Text('En objetivo'),
              ),
              DropdownMenuItem<EstadoEquipo?>(
                value: EstadoEquipo.enRiesgo,
                child: Text('En riesgo'),
              ),
              DropdownMenuItem<EstadoEquipo?>(
                value: EstadoEquipo.critico,
                child: Text('Crítico'),
              ),
            ],
            // Leandro: llama a onStatus para filtrar los equipos por su estado.
            onChanged: widget.onStatus,
          );
          final clearButton = OutlinedButton.icon(
            // Leandro: llama a onClear para quitar los filtros activos.
            onPressed: widget.hasActiveFilters ? widget.onClear : null,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Limpiar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: equiposBrand,
              disabledForegroundColor: equiposMuted.withValues(alpha: 0.45),
              side: BorderSide(
                color: widget.hasActiveFilters
                    ? equiposBorder
                    : equiposBorder.withValues(alpha: 0.55),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
            ),
          );

          if (constraints.maxWidth < 800) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 12),
                areaField,
                const SizedBox(height: 12),
                statusField,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: clearButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              SizedBox(width: 230, child: areaField),
              const SizedBox(width: 12),
              SizedBox(width: 250, child: statusField),
              const SizedBox(width: 12),
              clearButton,
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: equiposBorder),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: equiposMuted),
      prefixIcon: Icon(icon, size: 19, color: equiposMuted),
      prefixIconConstraints: const BoxConstraints(minWidth: 42),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: equiposBrand, width: 1.5),
      ),
    );
  }
}
