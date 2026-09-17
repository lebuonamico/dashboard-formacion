import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Controles de búsqueda, área y estado del dashboard.
/// Leandro: Recibe las selecciones de la pantalla y le avisa cuando el usuario las cambia.
/// Leandro: La lógica que decide qué equipos coinciden está en el provider de filtrados.
class EquiposFilters extends StatelessWidget {
  final List<String> areas;
  final String? selectedArea;
  final EstadoSemaforo? selectedStatus;
  // Leandro: ValueChanged<String> es una función que recibe un texto y no devuelve datos.
  // Leandro: Estos callbacks los define EquiposScreen para actualizar el estado en Riverpod.
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onArea;
  final ValueChanged<EstadoSemaforo?> onStatus;

  const EquiposFilters({
    super.key,
    required this.areas,
    required this.selectedArea,
    required this.selectedStatus,
    required this.onSearch,
    required this.onArea,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: equiposPanelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Leandro: Al escribir, TextField entrega el texto a onSearch. El recorrido es:
          // Leandro: control -> callback de la pantalla -> provider -> nuevos resultados.
          final searchField = TextField(
            onChanged: onSearch,
            decoration: _inputDecoration(
              'Buscar por equipo, área o líder',
              Icons.search,
            ),
          );
          // Leandro: String? admite null. La opción "Todas las áreas" envía null,
          // Leandro: que el provider interpreta como ausencia de filtro por área.
          final areaField = DropdownButtonFormField<String?>(
            initialValue: selectedArea,
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
              // Leandro: map crea una opción por área; ... las incorpora a esta lista.
              ...areas.map(
                (area) => DropdownMenuItem<String?>(
                  value: area,
                  child: Text(area, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: onArea,
          );
          // Leandro: El estado usa valores del enum, no textos: así se puede comparar
          // Leandro: directamente con equipo.semaforo. null equivale a "Todos los estados".
          final statusField = DropdownButtonFormField<EstadoSemaforo?>(
            initialValue: selectedStatus,
            isExpanded: true,
            decoration: _inputDecoration(
              'Todos los estados',
              Icons.traffic_outlined,
            ),
            items: const [
              DropdownMenuItem<EstadoSemaforo?>(
                value: null,
                child: Text('Todos los estados'),
              ),
              DropdownMenuItem<EstadoSemaforo?>(
                value: EstadoSemaforo.verde,
                child: Text('En objetivo'),
              ),
              DropdownMenuItem<EstadoSemaforo?>(
                value: EstadoSemaforo.amarillo,
                child: Text('En riesgo'),
              ),
              DropdownMenuItem<EstadoSemaforo?>(
                value: EstadoSemaforo.rojo,
                child: Text('Crítico'),
              ),
            ],
            onChanged: onStatus,
          );

          // Leandro: LayoutBuilder informa el ancho disponible dentro de este panel.
          // Leandro: Con poco espacio apilamos los controles; con más, van en una fila.
          if (constraints.maxWidth < 800) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 12),
                areaField,
                const SizedBox(height: 12),
                statusField,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              SizedBox(width: 230, child: areaField),
              const SizedBox(width: 12),
              SizedBox(width: 210, child: statusField),
            ],
          );
        },
      ),
    );
  }

  // Leandro: Decoración compartida por los tres controles para mantenerlos consistentes.
  // Leandro: Cambia su aspecto (bordes, iconos y fondo), no las reglas de filtrado.
  InputDecoration _inputDecoration(String hint, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: equiposBorder),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: equiposMuted),
      prefixIcon: Icon(icon, size: 19, color: equiposMuted),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(vertical: 13),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: equiposBrand, width: 1.5),
      ),
    );
  }
}
