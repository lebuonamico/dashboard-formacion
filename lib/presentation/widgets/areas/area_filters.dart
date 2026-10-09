import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/widgets/areas/area_styles.dart';
import 'package:flutter/material.dart';

class AreasFilters extends StatefulWidget {
  final String searchText;
  final EstadoSemaforo? selectedStatus;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearch;
  final ValueChanged<EstadoSemaforo?> onStatus;
  final VoidCallback onClear;

  const AreasFilters({
    super.key,
    required this.searchText,
    required this.selectedStatus,
    required this.hasActiveFilters,
    required this.onSearch,
    required this.onStatus,
    required this.onClear,
  });

  @override
  State<AreasFilters> createState() => _AreasFiltersState();
}

class _AreasFiltersState extends State<AreasFilters> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchText);
  }

  @override
  void didUpdateWidget(covariant AreasFilters oldWidget) {
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
      decoration: areasPanelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchField = TextField(
            controller: _searchController,
            onChanged: widget.onSearch,
            decoration: _inputDecoration(
              'Buscar por área o equipo general',
              Icons.search,
            ),
          );
          final statusField = DropdownButtonFormField<EstadoSemaforo?>(
            // La key fuerza a reconstruir el campo cuando "Limpiar" vuelve el
            // estado a null.
            key: ValueKey(widget.selectedStatus),
            initialValue: widget.selectedStatus,
            isExpanded: true,
            decoration: _inputDecoration(
              'Todos los estados',
              Icons.traffic_outlined,
            ),
            items: [
              const DropdownMenuItem<EstadoSemaforo?>(
                value: null,
                child: Text('Todos los estados'),
              ),
              for (final estado in EstadoSemaforo.values)
                DropdownMenuItem<EstadoSemaforo?>(
                  value: estado,
                  child: Text(estado.label),
                ),
            ],
            onChanged: widget.onStatus,
          );
          final clearButton = OutlinedButton.icon(
            onPressed: widget.hasActiveFilters ? widget.onClear : null,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Limpiar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: areasBrand,
              disabledForegroundColor: areasMuted.withValues(alpha: 0.45),
              side: BorderSide(
                color: widget.hasActiveFilters
                    ? areasBorder
                    : areasBorder.withValues(alpha: 0.55),
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
      borderSide: const BorderSide(color: areasBorder),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: areasMuted),
      prefixIcon: Icon(icon, size: 19, color: areasMuted),
      prefixIconConstraints: const BoxConstraints(minWidth: 42),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: areasBrand, width: 1.5),
      ),
    );
  }
}
