import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Bordes, relleno y colores salen del `inputDecorationTheme` de `AppTheme`.
InputDecoration filterInputDecoration(String hint, IconData icon) =>
    InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 19));

/// Selector compartido. La búsqueda es local y nunca modifica la selección.
/// El constructor habitual conserva la selección única de los períodos.
class FilterDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String hint;
  final IconData icon;
  final double width;
  final ValueChanged<T?>? onChanged;
  final String? tooltip;
  final bool multiSelect;
  final Set<T> selectedValues;
  final Set<T> incompatibleValues;
  final String Function(T)? itemTitleBuilder;
  final String? Function(T)? itemSubtitleBuilder;
  final ValueChanged<Set<T>>? onSelectionChanged;

  const FilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.width = 260,
    this.tooltip,
    this.incompatibleValues = const {},
    this.itemTitleBuilder,
    this.itemSubtitleBuilder,
  }) : multiSelect = false,
       selectedValues = const {},
       onSelectionChanged = null;

  const FilterDropdown.multiple({
    super.key,
    required this.selectedValues,
    required this.items,
    required this.hint,
    required this.icon,
    required this.onSelectionChanged,
    this.width = 260,
    this.tooltip,
    this.incompatibleValues = const {},
    this.itemTitleBuilder,
    this.itemSubtitleBuilder,
  }) : multiSelect = true,
       value = null,
       onChanged = null;

  @override
  State<FilterDropdown<T>> createState() => _FilterDropdownState<T>();
}

class _FilterDropdownState<T> extends State<FilterDropdown<T>> {
  double get _rowHeight {
    final baseHeight = widget.itemSubtitleBuilder == null ? 60.0 : 80.0;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return baseHeight * math.max(1.0, textScale);
  }

  final _menu = MenuController();
  final _search = TextEditingController();
  final _scroll = ScrollController();

  bool get _enabled => widget.multiSelect
      ? widget.onSelectionChanged != null
      : widget.onChanged != null;
  bool get _canClear =>
      widget.multiSelect || widget.items.any((item) => item.value == null);
  Set<T> get _selected => widget.multiSelect
      ? widget.selectedValues
      : {if (widget.value != null) widget.value as T};

  String _label(DropdownMenuItem<T> item) => item.child is Text
      ? (item.child as Text).data ?? ''
      : item.value.toString();

  void _toggle(T value) {
    final next = {..._selected};
    if (!next.remove(value)) next.add(value);
    widget.onSelectionChanged?.call(Set.unmodifiable(next));
  }

  void _clear() {
    if (widget.multiSelect) {
      widget.onSelectionChanged?.call({});
    } else {
      widget.onChanged?.call(null);
      _menu.close();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _list(List<DropdownMenuItem<T>> matches, double height) {
    if (matches.isEmpty) {
      return const Center(child: Text('Sin opciones disponibles'));
    }
    final needsScroll = matches.length * _rowHeight > height;
    return Listener(
      // La lista procesa primero la rueda; en sus extremos consumimos el
      // evento restante para que no desplace la página que está debajo.
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: needsScroll,
          trackVisibility: needsScroll,
          interactive: true,
          thickness: 6,
          radius: const Radius.circular(3),
          child: ListView.builder(
            controller: _scroll,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(right: 10),
            itemExtent: _rowHeight,
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final item = matches[index];
              final label = _label(item);
              final title =
                  widget.itemTitleBuilder?.call(item.value as T) ?? label;
              final subtitle = widget.itemSubtitleBuilder?.call(
                item.value as T,
              );
              final incompatible = widget.incompatibleValues.contains(
                item.value,
              );
              final child = Tooltip(
                message: incompatible
                    ? '$label: sin coincidencias con los demás filtros o el período actual.'
                    : label,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: incompatible || subtitle != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(height: 1.4),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (incompatible) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Sin coincidencias',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.4),
                        ),
                ),
              );
              if (widget.multiSelect) {
                return CheckboxMenuButton(
                  value: _selected.contains(item.value),
                  closeOnActivate: false,
                  isError: incompatible,
                  trailingIcon: incompatible
                      ? Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.error,
                        )
                      : null,
                  onChanged: item.enabled
                      ? (_) => _toggle(item.value as T)
                      : null,
                  child: child,
                );
              }
              return MenuItemButton(
                onPressed: item.enabled
                    ? () {
                        widget.onChanged?.call(item.value);
                        _menu.close();
                      }
                    : null,
                leadingIcon: _selected.contains(item.value)
                    ? const Icon(Icons.check, size: 18)
                    : const SizedBox(width: 18),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final incompatible = widget.incompatibleValues.intersection(selected);
    final query = ComplianceService.normalizeCourseName(_search.text);
    final options = widget.items.where((item) => item.value != null).toList();
    final matches = options
        .where(
          (item) => ComplianceService.normalizeCourseName(
            _label(item),
          ).contains(query),
        )
        .toList();
    // Dos grupos conservando el orden original, incluso al buscar.
    final ordered = [
      ...matches.where((item) => selected.contains(item.value)),
      ...matches.where((item) => !selected.contains(item.value)),
    ];
    final labels = [
      for (final item in options)
        if (selected.contains(item.value)) _label(item),
    ];
    final fullSummary = labels.isEmpty ? 'Todos' : labels.join(', ');
    final viewport = MediaQuery.sizeOf(context);
    final menuWidth = math.min(
      widget.width,
      math.max(0.0, viewport.width - 32),
    );
    final maxMenuHeight = math.min(
      420.0,
      math.max(120.0, viewport.height - 32),
    );
    final headerHeight = math.min(72.0, maxMenuHeight * 0.4);
    final footerHeight = _canClear ? math.min(48.0, maxMenuHeight * 0.25) : 0.0;
    final listHeight = math.min(
      math.max(_rowHeight, ordered.length * _rowHeight),
      math.min(280.0, maxMenuHeight - headerHeight - footerHeight),
    );
    final field = MenuAnchor(
      controller: _menu,
      useRootOverlay: true,
      onOpen: () {
        setState(() => _search.clear());
        if (_scroll.hasClients) _scroll.jumpTo(0);
      },
      menuChildren: [
        SizedBox(
          width: menuWidth,
          height: headerHeight + listHeight + footerHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: headerHeight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (_) {
                      if (_scroll.hasClients) _scroll.jumpTo(0);
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText: 'Buscar opciones...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ),
              SizedBox(height: listHeight, child: _list(ordered, listHeight)),
              if (_canClear)
                SizedBox(
                  height: footerHeight,
                  child: TextButton.icon(
                    onPressed: selected.isEmpty ? null : _clear,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: Text(
                      widget.multiSelect
                          ? 'Limpiar selecciones (${selected.length})'
                          : 'Todos',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      builder: (context, controller, child) => InkWell(
        onTap: !_enabled
            ? null
            : () {
                controller.isOpen ? controller.close() : controller.open();
              },
        child: InputDecorator(
          isEmpty: false,
          decoration: filterInputDecoration(widget.hint, widget.icon).copyWith(
            labelText: widget.hint,
            enabled: _enabled,
            suffixIcon: incompatible.isEmpty
                ? const Icon(Icons.arrow_drop_down)
                : Tooltip(
                    message:
                        '${incompatible.length} sin coincidencias con los demás filtros o el período actual.',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = DefaultTextStyle.of(context).style;
              final painter = TextPainter(
                text: TextSpan(text: fullSummary, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout(maxWidth: constraints.maxWidth);
              var summary = selected.length > 1 && painter.didExceedMaxLines
                  ? '${selected.length} seleccionados'
                  : fullSummary;
              if (selected.length > 1 && painter.didExceedMaxLines) {
                painter.text = TextSpan(text: summary, style: style);
                painter.layout(maxWidth: constraints.maxWidth);
                if (painter.didExceedMaxLines) {
                  summary = '${selected.length} selec.';
                }
              }
              painter.dispose();
              return Tooltip(
                message: fullSummary,
                child: Text(
                  summary,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? field
        : Tooltip(message: widget.tooltip!, child: field);
  }
}
