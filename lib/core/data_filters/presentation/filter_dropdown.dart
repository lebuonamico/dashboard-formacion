import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';

/// Borders, fill and colors come from AppTheme's `inputDecorationTheme`.
InputDecoration filterInputDecoration(String hint, IconData icon) =>
    InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 19));

/// Shared selector. The search is local and never changes the selection.
/// The default constructor keeps a single selection, as periods need.
///
/// From 840 px it opens as a menu under the field; below, as a bottom sheet
/// with rows a finger can hit and a search that does not raise the keyboard
/// by itself.
class FilterDropdown<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String hint;
  final IconData icon;

  /// Without the icon the value has more room, for narrow fields.
  final bool showIcon;
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
    this.showIcon = true,
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
    this.showIcon = true,
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

/// Rules shared by the menu and the bottom sheet.
extension _DropdownRules<T> on FilterDropdown<T> {
  bool get isEnabled =>
      multiSelect ? onSelectionChanged != null : onChanged != null;

  bool get canClear => multiSelect || items.any((item) => item.value == null);

  Set<T> get selection =>
      multiSelect ? selectedValues : {if (value != null) value as T};

  void toggle(T value) {
    final next = {...selection};
    if (!next.remove(value)) next.add(value);
    onSelectionChanged?.call(Set.unmodifiable(next));
  }

  /// Selected options first, both groups in their original order, filtered by
  /// [query] (already normalized). With [selectedFirst] false, the original
  /// order only.
  List<DropdownMenuItem<T>> ordered(String query, {bool selectedFirst = true}) {
    final selected = selection;
    final matches = items
        .where((item) => item.value != null)
        .where((item) => normalizeKey(_itemLabel(item)).contains(query))
        .toList();
    if (!selectedFirst) return matches;
    return [
      ...matches.where((item) => selected.contains(item.value)),
      ...matches.where((item) => !selected.contains(item.value)),
    ];
  }
}

String _itemLabel<T>(DropdownMenuItem<T> item) => item.child is Text
    ? (item.child as Text).data ?? ''
    : item.value.toString();

class _FilterDropdownState<T> extends State<FilterDropdown<T>> {
  double get _rowHeight {
    final baseHeight = widget.itemSubtitleBuilder == null ? 60.0 : 80.0;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return baseHeight * math.max(1.0, textScale);
  }

  final _menu = MenuController();
  final _search = TextEditingController();
  final _scroll = ScrollController();

  /// The bottom sheet is another route: it follows the latest configuration
  /// through this notifier (the selection, the incompatible values).
  late final ValueNotifier<FilterDropdown<T>> _latest;

  bool get _enabled => widget.isEnabled;
  bool get _canClear => widget.canClear;
  Set<T> get _selected => widget.selection;

  String _label(DropdownMenuItem<T> item) => _itemLabel(item);

  void _clear() {
    if (widget.multiSelect) {
      widget.onSelectionChanged?.call({});
    } else {
      widget.onChanged?.call(null);
      _menu.close();
    }
  }

  @override
  void initState() {
    super.initState();
    _latest = ValueNotifier(widget);
  }

  @override
  void didUpdateWidget(FilterDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sheet cannot be marked dirty while this subtree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _latest.value = widget;
    });
  }

  @override
  void dispose() {
    _latest.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(DropdownMenuItem<T> item) {
    if (widget.multiSelect) {
      widget.toggle(item.value as T);
    } else {
      widget.onChanged?.call(item.value);
      _menu.close();
    }
  }

  void _openSheet() => showModalBottomSheet<void>(
    context: context,
    // Above the shell, so it also covers the assistant button.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (_) => _OptionsSheet<T>(dropdown: _latest),
  );

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final incompatible = widget.incompatibleValues.intersection(selected);
    final options = widget.items.where((item) => item.value != null).toList();
    final ordered = widget.ordered(normalizeKey(_search.text));
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
      useRootOverlay: false,
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
                    decoration: InputDecoration(
                      hintText: 'Buscar opciones…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Borrar búsqueda',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: listHeight,
                child: _OptionsList<T>(
                  options: ordered,
                  searching: _search.text.trim().isNotEmpty,
                  height: listHeight,
                  rowHeight: _rowHeight,
                  controller: _scroll,
                  selected: selected,
                  dropdown: widget,
                  labelOf: _label,
                  onSelect: _select,
                ),
              ),
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
            : context.windowSize != WindowSize.expanded
            ? _openSheet
            : () {
                controller.isOpen ? controller.close() : controller.open();
              },
        child: InputDecorator(
          isEmpty: false,
          decoration:
              (widget.showIcon
                      ? filterInputDecoration(widget.hint, widget.icon)
                      : InputDecoration(hintText: widget.hint))
                  .copyWith(
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
          child: _SelectionSummary(
            fullSummary: fullSummary,
            selectedCount: selected.length,
          ),
        ),
      ),
    );
    return widget.tooltip == null
        ? field
        : Tooltip(message: widget.tooltip!, child: field);
  }
}

class _OptionsList<T> extends StatelessWidget {
  final List<DropdownMenuItem<T>> options;

  /// With a search typed, an empty list means nothing matches it.
  final bool searching;
  final double height;
  final double rowHeight;
  final ScrollController controller;
  final Set<T> selected;
  final FilterDropdown<T> dropdown;
  final String Function(DropdownMenuItem<T>) labelOf;
  final ValueChanged<DropdownMenuItem<T>> onSelect;

  const _OptionsList({
    required this.options,
    required this.searching,
    required this.height,
    required this.rowHeight,
    required this.controller,
    required this.selected,
    required this.dropdown,
    required this.labelOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Center(
        child: Text(
          searching
              ? 'Sin coincidencias con la búsqueda'
              : 'Sin opciones disponibles',
        ),
      );
    }
    final needsScroll = options.length * rowHeight > height;
    return Listener(
      // The list handles the wheel first; at its ends the leftover event is
      // consumed here so it does not scroll the page underneath.
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
        }
      },
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scrollbar(
          controller: controller,
          thumbVisibility: needsScroll,
          trackVisibility: needsScroll,
          interactive: true,
          thickness: 6,
          radius: const Radius.circular(3),
          child: ListView.builder(
            controller: controller,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(right: 10),
            itemExtent: rowHeight,
            itemCount: options.length,
            itemBuilder: (context, index) => _Option<T>(
              item: options[index],
              selected: selected,
              dropdown: dropdown,
              labelOf: labelOf,
              onSelect: onSelect,
            ),
          ),
        ),
      ),
    );
  }
}

class _Option<T> extends StatelessWidget {
  final DropdownMenuItem<T> item;
  final Set<T> selected;
  final FilterDropdown<T> dropdown;
  final String Function(DropdownMenuItem<T>) labelOf;
  final ValueChanged<DropdownMenuItem<T>> onSelect;

  const _Option({
    required this.item,
    required this.selected,
    required this.dropdown,
    required this.labelOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final label = labelOf(item);
    final incompatible = dropdown.incompatibleValues.contains(item.value);
    final child = _OptionLabel(
      label: label,
      title: dropdown.itemTitleBuilder?.call(item.value as T) ?? label,
      subtitle: dropdown.itemSubtitleBuilder?.call(item.value as T),
      incompatible: incompatible,
    );
    if (dropdown.multiSelect) {
      return CheckboxMenuButton(
        value: selected.contains(item.value),
        closeOnActivate: false,
        isError: incompatible,
        trailingIcon: incompatible
            ? Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              )
            : null,
        onChanged: item.enabled ? (_) => onSelect(item) : null,
        child: child,
      );
    }
    return MenuItemButton(
      onPressed: item.enabled ? () => onSelect(item) : null,
      leadingIcon: selected.contains(item.value)
          ? const Icon(Icons.check, size: 18)
          : const SizedBox(width: 18),
      child: child,
    );
  }
}

class _OptionLabel extends StatelessWidget {
  final String label;
  final String title;
  final String? subtitle;
  final bool incompatible;

  const _OptionLabel({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.incompatible,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Tooltip(
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
                      style: context.textTheme.labelMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (incompatible) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Sin coincidencias',
                      style: context.textTheme.labelMedium?.copyWith(
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
  }
}

/// The options as a bottom sheet, below 840 px. A single selection closes it
/// on choosing; a multiple one stays open until "Listo".
class _OptionsSheet<T> extends StatefulWidget {
  final ValueListenable<FilterDropdown<T>> dropdown;

  const _OptionsSheet({required this.dropdown});

  @override
  State<_OptionsSheet<T>> createState() => _OptionsSheetState<T>();
}

class _OptionsSheetState<T> extends State<_OptionsSheet<T>> {
  /// Short lists (months, years) are read at a glance: no search.
  static const _searchFrom = 13;

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<FilterDropdown<T>>(
        valueListenable: widget.dropdown,
        builder: (context, dropdown, _) {
          // A single choice (a month, a year) reads better in its natural
          // order, with the check on the chosen one.
          final options = dropdown.ordered(
            normalizeKey(_search.text),
            selectedFirst: dropdown.multiSelect,
          );
          final selected = dropdown.selection;
          final searchable =
              dropdown.items.where((item) => item.value != null).length >=
              _searchFrom;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    dropdown.hint,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (searchable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar opciones…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Borrar búsqueda',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(_search.clear),
                              ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Flexible(
                  child: options.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _search.text.trim().isNotEmpty
                                ? 'Sin coincidencias con la búsqueda'
                                : 'Sin opciones disponibles',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) => _SheetOption<T>(
                            item: options[index],
                            dropdown: dropdown,
                            selected: selected.contains(options[index].value),
                          ),
                        ),
                ),
                if (dropdown.multiSelect || dropdown.canClear) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                    child: Row(
                      children: [
                        if (dropdown.canClear)
                          TextButton.icon(
                            onPressed: dropdown.multiSelect && selected.isEmpty
                                ? null
                                : () {
                                    if (dropdown.multiSelect) {
                                      dropdown.onSelectionChanged?.call({});
                                    } else {
                                      dropdown.onChanged?.call(null);
                                      Navigator.pop(context);
                                    }
                                  },
                            icon: const Icon(
                              Icons.filter_alt_off_outlined,
                              size: 18,
                            ),
                            label: Text(
                              dropdown.multiSelect
                                  ? 'Limpiar selecciones (${selected.length})'
                                  : 'Todos',
                            ),
                          ),
                        const Spacer(),
                        if (dropdown.multiSelect)
                          FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Listo'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
}

class _SheetOption<T> extends StatelessWidget {
  final DropdownMenuItem<T> item;
  final FilterDropdown<T> dropdown;
  final bool selected;

  const _SheetOption({
    required this.item,
    required this.dropdown,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final value = item.value as T;
    final label = _itemLabel(item);
    final incompatible = dropdown.incompatibleValues.contains(value);
    final entity = dropdown.itemSubtitleBuilder?.call(value);
    final error = context.colorScheme.error;
    final title = Text(
      dropdown.itemTitleBuilder?.call(value) ?? label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final subtitle = entity == null && !incompatible
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entity != null) Text(entity),
              if (incompatible)
                Text('Sin coincidencias', style: TextStyle(color: error)),
            ],
          );

    if (dropdown.multiSelect) {
      return CheckboxListTile(
        value: selected,
        controlAffinity: ListTileControlAffinity.leading,
        isError: incompatible,
        title: title,
        subtitle: subtitle,
        secondary: incompatible
            ? Icon(Icons.warning_amber_rounded, color: error)
            : null,
        onChanged: item.enabled ? (_) => dropdown.toggle(value) : null,
      );
    }
    return ListTile(
      selected: selected,
      leading: Icon(selected ? Icons.check : null),
      title: title,
      subtitle: subtitle,
      enabled: item.enabled,
      onTap: () {
        dropdown.onChanged?.call(value);
        Navigator.pop(context);
      },
    );
  }
}

/// The selected labels, or "N seleccionados" / "N selec." when they do not
/// fit in one line.
class _SelectionSummary extends StatelessWidget {
  final String fullSummary;
  final int selectedCount;

  const _SelectionSummary({
    required this.fullSummary,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = DefaultTextStyle.of(context).style;
      final painter = TextPainter(
        text: TextSpan(text: fullSummary, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout(maxWidth: constraints.maxWidth);
      var summary = selectedCount > 1 && painter.didExceedMaxLines
          ? '$selectedCount seleccionados'
          : fullSummary;
      if (selectedCount > 1 && painter.didExceedMaxLines) {
        painter.text = TextSpan(text: summary, style: style);
        painter.layout(maxWidth: constraints.maxWidth);
        if (painter.didExceedMaxLines) {
          summary = '$selectedCount selec.';
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
  );
}
