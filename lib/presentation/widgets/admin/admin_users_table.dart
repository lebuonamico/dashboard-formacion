import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/etiqueta_color.dart';
import 'package:app_finnegans/presentation/widgets/shared/result_pagination.dart';

class AdminUsuariosTable extends StatefulWidget {
  static const usuariosPorPagina = 8;

  final List<UsuarioAutorizado> usuarios;

  /// Para la columna Lidera. `null` mientras carga o sin base conectada.
  final EstructuraOrganizacional? estructura;

  /// Para la columna Pertenece a. `null` mientras carga.
  final List<Empleado>? nomina;
  final String? emailSeleccionado;
  final String? emailPropio;
  final ValueChanged<String?> onSeleccionar;

  const AdminUsuariosTable({
    super.key,
    required this.usuarios,
    this.estructura,
    this.nomina,
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
          decoration: context.panel(),
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
                      headingRowColor: WidgetStatePropertyAll(
                        context.colorScheme.surfaceContainerLow,
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
                            'Lidera',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Pertenece a',
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
    final cs = context.colorScheme;
    final colores = context.colores;
    final seleccionado = usuario.email == widget.emailSeleccionado;
    final esPropio = usuario.esMismoUsuario(widget.emailPropio);
    final rol = usuario.rolConocido;
    final marca = ParColores(cs.onPrimaryContainer, cs.primaryContainer);

    return DataRow(
      selected: seleccionado,
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? cs.primary.withValues(alpha: 0.06)
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
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (esPropio) ...[
                const SizedBox(width: 8),
                EtiquetaColor(texto: 'Vos', colores: marca),
              ],
            ],
          ),
        ),
        DataCell(
          rol == null
              ? EtiquetaColor(
                  texto: usuario.rol.isEmpty ? 'Sin rol' : usuario.rol,
                  colores: colores.advertencia,
                  icono: Icons.help_outline,
                )
              : EtiquetaColor(texto: rol.label, colores: marca),
        ),
        DataCell(_alcance(usuario)),
        DataCell(_pertenencia(usuario)),
        DataCell(
          EtiquetaColor(
            texto: usuario.estado.label,
            colores: coloresEstadoUsuario(colores, usuario.estado),
          ),
        ),
        DataCell(_sello(usuario.ffAlta)),
        DataCell(_sello(usuario.ffBloqueo)),
        DataCell(_sello(usuario.ffEliminar)),
      ],
    );
  }

  /// Qué ve el usuario: toda la empresa, o las áreas o los equipos que
  /// lidera según su rol.
  Widget _alcance(UsuarioAutorizado usuario) {
    final rol = usuario.rolConocido;
    // Los gestores ven todo aunque la estructura no haya cargado.
    final texto = rol != null && rol.esGestor
        ? 'Toda la empresa'
        : widget.estructura?.lidera(rol: rol, email: usuario.email) ?? '—';
    return _celdaTexto(texto, advertencia: texto.startsWith('Sin '));
  }

  /// Equipo y área de su fila en la nómina, buscada por email. Solo para los
  /// líderes: puede no coincidir con lo que lideran.
  Widget _pertenencia(UsuarioAutorizado usuario) {
    final rol = usuario.rolConocido;
    final nomina = widget.nomina;
    if (nomina == null || (rol != RolUsuario.lider && rol != RolUsuario.area)) {
      return _celdaTexto('—');
    }
    final empleado = Empleado.porMail(nomina, usuario.email);
    return _celdaTexto(
      EstructuraOrganizacional.pertenencia(empleado),
      advertencia: empleado == null,
    );
  }

  Widget _celdaTexto(String texto, {bool advertencia = false}) =>
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Tooltip(
          message: texto,
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: advertencia
                  ? context.colores.advertencia.texto
                  : context.colores.textoIntermedio,
            ),
          ),
        ),
      );

  Widget _sello(DateTime? fecha) => Text(
    formatearSello(fecha),
    style: TextStyle(
      fontSize: 13,
      color: fecha == null
          ? context.colores.textoTenue
          : context.colores.textoIntermedio,
    ),
  );
}
