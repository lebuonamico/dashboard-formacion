import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/plan_formacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/seniority_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edita las horas mensuales requeridas por categoría para cada seniority.
/// Cada guardado es una versión que rige desde el mes elegido: los meses
/// anteriores conservan el plan que tenían.
class PlanFormacionEditor extends ConsumerStatefulWidget {
  const PlanFormacionEditor({super.key});

  @override
  ConsumerState<PlanFormacionEditor> createState() =>
      _PlanFormacionEditorState();
}

class _PlanFormacionEditorState extends ConsumerState<PlanFormacionEditor> {
  static const _anchoSeniority = 170.0;
  static const _anchoHoras = 104.0;
  static const _anchoTotal = 90.0;

  final _controladores = {
    for (final seniority in Seniority.values)
      for (final tipo in TipoCurso.values)
        (seniority, tipo): TextEditingController(),
  };

  late int _anio;
  late int _mes;
  PlanesFormacion? _planes;

  /// Plan vigente en el mes elegido: contra él se marcan los cambios.
  PlanFormacion? _base;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _anio = hoy.year;
    _mes = hoy.month;
    // El formulario se carga cada vez que cambian los planes guardados (al
    // abrir la pantalla y después de guardar).
    ref.listenManual(planesFormacionProvider, (_, siguiente) {
      if (siguiente case AsyncData(:final value)) {
        _planes = value;
        _cargar(value.vigenteEn(_anio, _mes));
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    for (final controlador in _controladores.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  /// Pone el plan en el formulario y lo toma como base de los cambios.
  void _cargar(PlanFormacion plan, {bool comoBase = true}) {
    if (comoBase) _base = plan;
    for (final MapEntry(key: (seniority, tipo), value: controlador)
        in _controladores.entries) {
      controlador.text = _texto(plan.horasRequeridas(seniority)[tipo]!);
    }
  }

  static String _texto(double horas) => horas == horas.roundToDouble()
      ? horas.toStringAsFixed(0)
      : horas.toString().replaceAll('.', ',');

  /// Acepta coma decimal. Se redondea a 2 decimales, como la base.
  static double? _horas(String texto) {
    final valor = double.tryParse(texto.trim().replaceAll(',', '.'));
    return valor == null ? null : (valor * 100).round() / 100;
  }

  double? _valor(Seniority seniority, TipoCurso tipo) =>
      _horas(_controladores[(seniority, tipo)]!.text);

  /// El plan del formulario, o `null` si algún campo es inválido.
  PlanFormacion? get _planEditado {
    final horas = <Seniority, Map<TipoCurso, double>>{};
    for (final seniority in Seniority.values) {
      for (final tipo in TipoCurso.values) {
        final valor = _valor(seniority, tipo);
        if (PlanFormacion.errorHoras(valor) != null) return null;
        (horas[seniority] ??= {})[tipo] = valor!;
      }
    }
    return PlanFormacion(horas);
  }

  bool get _hayCambios => _planEditado != _base;

  bool get _mesPasado {
    final hoy = DateTime.now();
    return DateTime(_anio, _mes).isBefore(DateTime(hoy.year, hoy.month));
  }

  Future<void> _elegirMes(int anio, int mes) async {
    if (anio == _anio && mes == _mes) return;
    if (!await _confirmarDescarte()) return;
    setState(() {
      _anio = anio;
      _mes = mes;
      _cargar(_planes!.vigenteEn(anio, mes));
    });
  }

  Future<bool> _confirmarDescarte() async {
    if (!_hayCambios) return true;
    final descartar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text(
          'Hay cambios sin guardar en el plan. ¿Querés descartarlos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return descartar ?? false;
  }

  Future<void> _guardar(PlanFormacion plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final vigencia = '${nombreMes(_mes)} $_anio';
    setState(() => _guardando = true);
    try {
      await ref
          .read(planFormacionRepositoryProvider)
          .guardarVersion(
            VersionPlanFormacion(
              vigenteDesde: DateTime(_anio, _mes),
              plan: plan,
            ),
          );
      // Recalcula todo el cumplimiento y recarga el formulario.
      ref.invalidate(planesFormacionProvider);
      await ref.read(planesFormacionProvider.future);
      messenger.showSnackBar(
        SnackBar(content: Text('Plan guardado: rige desde $vigencia.')),
      );
    } on FormatException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar el plan: $error')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planesAsync = ref.watch(planesFormacionProvider);
    final planes = _planes;
    if (planesAsync.hasError && planes == null) {
      return Text(
        'No se pudo cargar el plan de formación: ${planesAsync.error}',
        style: TextStyle(color: context.colores.peligro.texto),
      );
    }
    if (planes == null || _base == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final planEditado = _planEditado;
    final hayCambios = planEditado != _base;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVigencia(planes),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildTabla(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton.icon(
              key: const Key('plan_restaurar'),
              onPressed: _guardando
                  ? null
                  : () => setState(
                      () =>
                          _cargar(PlanFormacion.porDefecto(), comoBase: false),
                    ),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restaurar valores por defecto'),
            ),
            TextButton(
              key: const Key('plan_descartar'),
              onPressed: hayCambios && !_guardando
                  ? () => setState(() => _cargar(_base!))
                  : null,
              child: const Text('Descartar cambios'),
            ),
            FilledButton.icon(
              key: const Key('plan_guardar'),
              onPressed: planEditado != null && hayCambios && !_guardando
                  ? () => _guardar(planEditado)
                  : null,
              icon: _guardando
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar plan'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVigencia(PlanesFormacion planes) {
    final cs = context.colorScheme;
    final colores = context.colores;
    final hoy = DateTime.now();
    final primerAnio = [
      hoy.year - 1,
      ...planes.versiones.map((version) => version.vigenteDesde.year),
    ].reduce((a, b) => a < b ? a : b);
    final anios = [for (var a = primerAnio; a <= hoy.year + 1; a++) a];
    final vigente = planes.versionVigenteEn(_anio, _mes);
    final siguiente = planes.versiones
        .where((version) => version.vigenteDesde.isAfter(DateTime(_anio, _mes)))
        .firstOrNull;
    final estiloNota = TextStyle(fontSize: 13, color: cs.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Rige desde',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            DropdownButton<int>(
              key: const Key('plan_mes'),
              value: _mes,
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(nombreMes(m))),
              ],
              onChanged: _guardando
                  ? null
                  : (mes) => mes == null ? null : _elegirMes(_anio, mes),
            ),
            DropdownButton<int>(
              key: const Key('plan_anio'),
              value: _anio,
              items: [
                for (final anio in anios)
                  DropdownMenuItem(value: anio, child: Text('$anio')),
              ],
              onChanged: _guardando
                  ? null
                  : (anio) => anio == null ? null : _elegirMes(anio, _mes),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          vigente == null
              ? 'Hasta ahora ese mes usa los valores por defecto.'
              : vigente.vigenteDesde == DateTime(_anio, _mes)
              ? 'Estás editando la versión que rige desde ese mes.'
              : 'Hasta ahora ese mes usa la versión de '
                    '${_etiquetaMes(vigente.vigenteDesde)}.',
          style: estiloNota,
        ),
        if (siguiente != null)
          Text(
            'Lo que guardes rige hasta ${_etiquetaMes(siguiente.vigenteDesde)}, '
            'cuando empieza la versión siguiente.',
            style: estiloNota,
          ),
        if (_mesPasado)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: colores.advertencia.texto,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Es un mes pasado: guardar recalcula los meses ya '
                    'evaluados desde ${nombreMes(_mes)} $_anio.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colores.advertencia.texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (planes.versiones.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final version in planes.versiones)
                ActionChip(
                  label: Text('Desde ${_etiquetaMes(version.vigenteDesde)}'),
                  onPressed: _guardando
                      ? null
                      : () => _elegirMes(
                          version.vigenteDesde.year,
                          version.vigenteDesde.month,
                        ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _etiquetaMes(DateTime fecha) =>
      '${nombreMes(fecha.month).toLowerCase()} ${fecha.year}';

  Widget _buildTabla() {
    final cs = context.colorScheme;
    final colores = context.colores;
    final estiloEncabezado = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const FixedColumnWidth(_anchoSeniority),
        for (var i = 1; i <= TipoCurso.values.length; i++)
          i: const FixedColumnWidth(_anchoHoras),
        TipoCurso.values.length + 1: const FixedColumnWidth(_anchoTotal),
      },
      children: [
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Seniority', style: estiloEncabezado),
            ),
            for (final tipo in TipoCurso.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 12),
                child: Tooltip(
                  message: tipo.label,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colores.categoria(tipo).texto,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(tipo.labelCorto, style: estiloEncabezado),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Total',
                textAlign: TextAlign.end,
                style: estiloEncabezado,
              ),
            ),
          ],
        ),
        for (final seniority in Seniority.values) _fila(seniority),
      ],
    );
  }

  TableRow _fila(Seniority seniority) {
    final cs = context.colorScheme;
    final valores = [
      for (final tipo in TipoCurso.values) _valor(seniority, tipo),
    ];
    // Con un campo inválido no hay total que mostrar.
    final total =
        valores.every((valor) => PlanFormacion.errorHoras(valor) == null)
        ? valores.fold<double>(0, (suma, valor) => suma + valor!)
        : null;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SeniorityChip(seniority: seniority),
          ),
        ),
        for (final tipo in TipoCurso.values) _campo(seniority, tipo),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (total == 0)
              Tooltip(
                message: 'Sin objetivo: cuenta como cumplido.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: context.colores.advertencia.texto,
                ),
              ),
            const SizedBox(width: 4),
            Text(
              total == null ? '—' : '${_texto(total)} h',
              key: Key('plan_total_${seniority.name}'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _campo(Seniority seniority, TipoCurso tipo) {
    final cs = context.colorScheme;
    final valor = _valor(seniority, tipo);
    final error = PlanFormacion.errorHoras(valor);
    final modificado =
        error == null && valor != _base!.horasRequeridas(seniority)[tipo];

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
      child: TextField(
        key: Key('plan_${seniority.name}_${tipo.name}'),
        controller: _controladores[(seniority, tipo)],
        enabled: !_guardando,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          suffixText: 'h',
          errorText: error,
          errorMaxLines: 2,
          filled: modificado,
          fillColor: cs.primaryContainer.withValues(alpha: 0.45),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
