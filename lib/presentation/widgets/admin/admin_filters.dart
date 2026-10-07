import 'package:flutter/material.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_styles.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';

class AdminFilters extends StatefulWidget {
  final String busqueda;
  final RolUsuario? rolSeleccionado;
  final EstadoUsuario? estadoSeleccionado;
  final bool hayFiltrosActivos;
  final ValueChanged<String> onBuscar;
  final ValueChanged<RolUsuario?> onRol;
  final ValueChanged<EstadoUsuario?> onEstado;
  final VoidCallback onLimpiar;

  const AdminFilters({
    super.key,
    required this.busqueda,
    required this.rolSeleccionado,
    required this.estadoSeleccionado,
    required this.hayFiltrosActivos,
    required this.onBuscar,
    required this.onRol,
    required this.onEstado,
    required this.onLimpiar,
  });

  @override
  State<AdminFilters> createState() => _AdminFiltersState();
}

class _AdminFiltersState extends State<AdminFilters> {
  late final TextEditingController _controladorBusqueda;

  @override
  void initState() {
    super.initState();
    _controladorBusqueda = TextEditingController(text: widget.busqueda);
  }

  @override
  void didUpdateWidget(covariant AdminFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busqueda != _controladorBusqueda.text) {
      _controladorBusqueda.text = widget.busqueda;
    }
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: equiposPanelDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final campoBusqueda = TextField(
            key: const Key('admin_buscar'),
            controller: _controladorBusqueda,
            onChanged: widget.onBuscar,
            decoration: adminInputDecoration('Buscar por email', Icons.search),
          );
          final campoRol = DropdownButtonFormField<RolUsuario?>(
            initialValue: widget.rolSeleccionado,
            isExpanded: true,
            decoration: adminInputDecoration(
              'Todos los roles',
              Icons.badge_outlined,
            ),
            items: [
              const DropdownMenuItem<RolUsuario?>(
                value: null,
                child: Text('Todos los roles'),
              ),
              ...RolUsuario.values.map(
                (rol) => DropdownMenuItem<RolUsuario?>(
                  value: rol,
                  child: Text(rol.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: widget.onRol,
          );
          final campoEstado = DropdownButtonFormField<EstadoUsuario?>(
            initialValue: widget.estadoSeleccionado,
            isExpanded: true,
            decoration: adminInputDecoration(
              'Todos los estados',
              Icons.toggle_on_outlined,
            ),
            items: [
              const DropdownMenuItem<EstadoUsuario?>(
                value: null,
                child: Text('Todos los estados'),
              ),
              ...EstadoUsuario.values.map(
                (estado) => DropdownMenuItem<EstadoUsuario?>(
                  value: estado,
                  child: Text(estado.label),
                ),
              ),
            ],
            onChanged: widget.onEstado,
          );
          final botonLimpiar = OutlinedButton.icon(
            onPressed: widget.hayFiltrosActivos ? widget.onLimpiar : null,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Limpiar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: equiposBrand,
              disabledForegroundColor: equiposMuted.withValues(alpha: 0.45),
              side: BorderSide(
                color: widget.hayFiltrosActivos
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
                campoBusqueda,
                const SizedBox(height: 12),
                campoRol,
                const SizedBox(height: 12),
                campoEstado,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: botonLimpiar),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: campoBusqueda),
              const SizedBox(width: 12),
              SizedBox(width: 230, child: campoRol),
              const SizedBox(width: 12),
              SizedBox(width: 230, child: campoEstado),
              const SizedBox(width: 12),
              botonLimpiar,
            ],
          );
        },
      ),
    );
  }
}
