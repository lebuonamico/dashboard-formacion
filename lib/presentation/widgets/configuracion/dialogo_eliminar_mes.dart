import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/repositorios/eliminacion_por_mes_repository.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:flutter/material.dart';

String etiquetaMes(MesConRegistros mes) => '${nombreMes(mes.mes)} ${mes.anio}';

/// Pide el mes a borrar entre los que tienen datos y confirma la eliminación.
/// [descripcion] nombra los registros en el aviso, por ejemplo "de horas CRM".
Future<MesConRegistros?> mostrarDialogoEliminarMes(
  BuildContext context, {
  required List<MesConRegistros> meses,
  required String descripcion,
}) {
  return showDialog<MesConRegistros>(
    context: context,
    builder: (_) => _DialogoEliminarMes(meses: meses, descripcion: descripcion),
  );
}

class _DialogoEliminarMes extends StatefulWidget {
  final List<MesConRegistros> meses;
  final String descripcion;

  const _DialogoEliminarMes({required this.meses, required this.descripcion});

  @override
  State<_DialogoEliminarMes> createState() => _DialogoEliminarMesState();
}

class _DialogoEliminarMesState extends State<_DialogoEliminarMes> {
  late MesConRegistros _seleccionado = widget.meses.first;

  String _registros(int cantidad) =>
      cantidad == 1 ? '1 registro' : '$cantidad registros';

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Eliminar registros de un mes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<MesConRegistros>(
                key: const Key('eliminar_mes_selector'),
                initialValue: _seleccionado,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mes',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final mes in widget.meses)
                    DropdownMenuItem(
                      value: mes,
                      child: Text(
                        '${etiquetaMes(mes)} · ${_registros(mes.cantidad)}',
                      ),
                    ),
                ],
                onChanged: (mes) {
                  if (mes != null) setState(() => _seleccionado = mes);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Se van a borrar ${_registros(_seleccionado.cantidad)} '
                '${widget.descripcion} de ${etiquetaMes(_seleccionado)}. '
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                  fontSize: 14,
                  color: context.colores.textoIntermedio,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('eliminar_mes_confirmar'),
                    onPressed: () => Navigator.of(context).pop(_seleccionado),
                    style: FilledButton.styleFrom(backgroundColor: cs.error),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
