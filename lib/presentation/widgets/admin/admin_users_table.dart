import 'package:flutter/material.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';
import 'package:app_finnegans/presentation/widgets/teams/team_styles.dart';

class AdminUsuariosTable extends StatefulWidget {
  static const usuariosPorPagina = 8;

  final List<UsuarioAutorizado> usuarios;
  final String? emailSeleccionado;
  final String? emailPropio;
  final ValueChanged<String?> onSeleccionar;

  const AdminUsuariosTable({
    super.key,
    required this.usuarios,
    required this.emailSeleccionado,
    required this.emailPropio,
    required this.onSeleccionar,
  });

  @override
  State<AdminUsuariosTable> createState() => _AdminUsuariosTableState();
}

class _AdminUsuariosTableState extends State<AdminUsuariosTable> {
  int _paginaActual = 0;

  @override
  void didUpdateWidget(covariant AdminUsuariosTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuarios != widget.usuarios) {
      _paginaActual = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    const porPagina = AdminUsuariosTable.usuariosPorPagina;
    final total = widget.usuarios.length;
    final totalPaginas = total == 0 ? 1 : (total + porPagina - 1) ~/ porPagina;
    final paginaSegura = _paginaActual.clamp(0, totalPaginas - 1);
    final inicio = paginaSegura * porPagina;
    final finCalculado = inicio + porPagina;
    final fin = finCalculado > total ? total : finCalculado;
    final visibles = widget.usuarios.sublist(inicio, fin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalPaginas > 1) ...[
          PaginacionResultados(
            paginaActual: paginaSegura,
            cantidadPaginas: totalPaginas,
            desde: inicio + 1,
            hasta: fin,
            totalResultados: total,
            etiquetaResultados: 'usuarios',
            icono: Icons.manage_accounts_outlined,
            onPrevious: paginaSegura > 0
                ? () => setState(() => _paginaActual = paginaSegura - 1)
                : null,
            onNext: paginaSegura < totalPaginas - 1
                ? () => setState(() => _paginaActual = paginaSegura + 1)
                : null,
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          decoration: equiposPanelDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth < 900
                          ? 900
                          : constraints.maxWidth,
                    ),
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: const WidgetStatePropertyAll(
                        equiposBackground,
                      ),
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 64,
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Email',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Rol',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Estado',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Fecha de alta',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Fecha de bloqueo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Fecha de eliminación',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: visibles.map(_buildRow).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(UsuarioAutorizado usuario) {
    final seleccionado = usuario.email == widget.emailSeleccionado;
    final esPropio = usuario.esMismoUsuario(widget.emailPropio);
    final estado = coloresEstadoUsuario(usuario.estado);
    final rol = usuario.rolConocido;

    return DataRow(
      selected: seleccionado,
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? equiposBrand.withValues(alpha: 0.06)
            : null,
      ),
      onSelectChanged: (valor) =>
          widget.onSeleccionar(valor == true ? usuario.email : null),
      cells: [
        DataCell(
          Row(
            children: [
              Text(
                usuario.email,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: equiposInk,
                ),
              ),
              if (esPropio) ...[
                const SizedBox(width: 8),
                const AdminChip(
                  label: 'Vos',
                  texto: Color(0xFF1D4ED8),
                  fondo: Color(0xFFEFF6FF),
                ),
              ],
            ],
          ),
        ),
        DataCell(
          rol == null
              ? AdminChip(
                  label: usuario.rol.isEmpty ? 'Sin rol' : usuario.rol,
                  texto: const Color(0xFFD97706),
                  fondo: const Color(0xFFFEF3C7),
                  icono: Icons.help_outline,
                )
              : AdminChip(
                  label: rol.label,
                  texto: const Color(0xFF1D4ED8),
                  fondo: const Color(0xFFEFF6FF),
                ),
        ),
        DataCell(
          AdminChip(
            label: usuario.estado.label,
            texto: estado.texto,
            fondo: estado.fondo,
          ),
        ),
        DataCell(_sello(usuario.ffAlta)),
        DataCell(_sello(usuario.ffBloqueo)),
        DataCell(_sello(usuario.ffEliminar)),
      ],
    );
  }

  Widget _sello(DateTime? fecha) => Text(
    formatearSello(fecha),
    style: TextStyle(
      fontSize: 13,
      color: fecha == null ? const Color(0xFF94A3B8) : const Color(0xFF334155),
    ),
  );
}
