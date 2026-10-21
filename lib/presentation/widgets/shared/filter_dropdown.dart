import 'package:flutter/material.dart';

/// Decoración de los campos de la barra de filtros (buscador y desplegables).
/// Bordes, relleno y colores salen del `inputDecorationTheme` de `AppTheme`.
InputDecoration filtroInputDecoration(String hint, IconData icon) =>
    InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 19));

/// Desplegable de una [FilterBar]. Sirve para listas cerradas y chicas
/// (estado, seniority, tipo, año, mes); lo demás se filtra por texto.
class FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final String hint;
  final IconData icon;

  /// Ancho cuando la barra está en una fila. En columna ocupa todo el ancho.
  final double width;

  /// Con `null` el desplegable queda deshabilitado.
  final ValueChanged<T?>? onChanged;

  /// Mensaje al pasar el mouse, útil para explicar por qué está deshabilitado.
  final String? tooltip;

  const FilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.width = 260,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final campo = DropdownButtonFormField<T>(
      // La key reconstruye el campo cuando el valor cambia desde afuera
      // (por ejemplo con "Limpiar"), porque initialValue sólo se lee al crearlo.
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: filtroInputDecoration(hint, icon),
      items: items,
      onChanged: onChanged,
    );

    return tooltip == null ? campo : Tooltip(message: tooltip!, child: campo);
  }
}
