import 'package:flutter/material.dart';

const _bordeFiltro = Color(0xFFE2E8F0);
const _textoSecundario = Color(0xFF64748B);
const _marcaFiltro = Color(0xFF0D53C3);

/// Decoración de los campos de la barra de filtros (buscador y desplegables).
InputDecoration filtroInputDecoration(String hint, IconData icon) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: _bordeFiltro),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: _textoSecundario),
    prefixIcon: Icon(icon, size: 19, color: _textoSecundario),
    prefixIconConstraints: const BoxConstraints(minWidth: 42),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: _marcaFiltro, width: 1.5),
    ),
  );
}

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
