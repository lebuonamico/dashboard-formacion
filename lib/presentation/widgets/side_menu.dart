import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/side_menu_providers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _anchoSideMenu = 260;

/// Mismo alto que `AppTopBar` y los top bars de cada pantalla, para que la
/// línea bajo el logo continúe exactamente la del top bar.
const double _altoHeader = 64;

const Duration _duracionAnimacion = Duration(milliseconds: 220);

class SideMenu extends ConsumerStatefulWidget {
  const SideMenu({super.key});

  @override
  ConsumerState<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends ConsumerState<SideMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animacion;

  // La pestaña sobresale del borde de la sidebar: si fuera hija del Row de la
  // pantalla quedaría pintada debajo del contenido y fuera del hit-test. Por
  // eso va en el overlay. Se ubica con overlayChildLayoutBuilder y no con un
  // CompositedTransformFollower: el Tooltip de la pestaña también usa ese
  // builder, y Flutter lo rompe si encuentra un follower entre él y el Overlay.
  final _pestana = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // Arranca en el estado actual: al navegar a otra pantalla no re-anima.
    _controller = AnimationController(
      vsync: this,
      duration: _duracionAnimacion,
      value: ref.read(sideMenuDesplegadoProvider) ? 1 : 0,
    );
    _animacion = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _pestana.show();
  }

  @override
  void dispose() {
    _animacion.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sideMenuDesplegadoProvider, (_, desplegado) {
      desplegado ? _controller.forward() : _controller.reverse();
    });
    final desplegado = ref.watch(sideMenuDesplegadoProvider);

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _pestana,
      overlayChildBuilder: (_, info) => _buildPestana(desplegado, info),
      child: AnimatedBuilder(
        animation: _animacion,
        // El contenido se arma siempre con el ancho completo y se recorta: la
        // sidebar se desliza como un cajón en lugar de comprimir los textos.
        builder: (context, contenido) => SizedBox(
          width: _anchoSideMenu * _animacion.value,
          child: Visibility(
            // Oculta del todo, los ítems no reciben foco ni quedan en la
            // semántica.
            visible: _animacion.value > 0,
            // Conserva el alto completo: con el SizedBox.shrink por defecto el
            // Row de la pantalla la centraría verticalmente y la pestaña
            // saltaría a la mitad de la altura al plegarse.
            replacement: const SizedBox(height: double.infinity),
            child: ClipRect(
              child: OverflowBox(
                minWidth: _anchoSideMenu,
                maxWidth: _anchoSideMenu,
                alignment: Alignment.centerRight,
                child: contenido,
              ),
            ),
          ),
        ),
        child: _buildContenido(context),
      ),
    );
  }

  /// Se vuelve a ejecutar en cada layout: `info` trae el tamaño y la posición
  /// de la sidebar en coordenadas del overlay, así la pestaña sigue el ancho
  /// animado y las transiciones de página.
  Widget _buildPestana(bool desplegado, OverlayChildLayoutInfo info) {
    const margenOculta = 8.0;
    const radio = _PestanaToggle.diametro / 2;
    final progreso = _animacion.value;
    final borde = MatrixUtils.transformPoint(
      info.childPaintTransform,
      Offset(info.childSize.width, 0),
    );
    // Desplegada: centrada sobre el borde. Oculta: entera, pegada al margen
    // izquierdo de la pantalla.
    final desplazamiento = (margenOculta + radio) * (1 - progreso);

    return Positioned(
      left: borde.dx - radio + desplazamiento,
      top: borde.dy + _altoHeader - 0.5 - radio,
      child: _PestanaToggle(
        progreso: progreso,
        desplegado: desplegado,
        onTap: () =>
            ref.read(sideMenuDesplegadoProvider.notifier).state = !desplegado,
      ),
    );
  }

  Widget _buildContenido(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final currentPath = uri.path;
    final requestedOrigin = uri.queryParameters['origen'];
    const validOrigins = {'dashboard', 'areas', 'equipos'};
    final origin = validOrigins.contains(requestedOrigin)
        ? requestedOrigin
        : null;

    bool isSelected(String section, String path) {
      if (origin != null) return origin == section;
      return currentPath.startsWith(path);
    }

    final auth = ref.watch(authControllerProvider);
    final mostrarAdmin = auth.esAdmin || !auth.enabled;

    return Container(
      width: _anchoSideMenu,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con Logo
          Container(
            height: _altoHeader,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D53C3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finnegans',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D53C3),
                      ),
                    ),
                    Text(
                      'Portal de formación interna',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items de navegación
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _MenuItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Inicio',
                  isSelected: isSelected('dashboard', '/dashboard'),
                  onTap: () {
                    context.push(
                      '/dashboard',
                    ); // Navega a la pantalla de dashboard
                  },
                ),
                _MenuItem(
                  icon: Icons.account_tree_outlined,
                  label: 'Áreas',
                  isSelected: isSelected('areas', '/areas'),
                  onTap: () {
                    context.push('/areas'); // Navega a la pantalla de áreas
                  },
                ),
                _MenuItem(
                  icon: Icons.group_work,
                  label: 'Equipos',
                  isSelected: isSelected('equipos', '/equipos'),
                  onTap: () {
                    context.push('/equipos'); // Navega a la pantalla de equipos
                  },
                ),
                _MenuItem(
                  icon: Icons.people_outline,
                  label: 'Empleados',
                  isSelected: isSelected('empleados', '/empleados'),
                  onTap: () {
                    context.push(
                      '/empleados',
                    ); // Navega a la pantalla de empleados
                  },
                ),

                _MenuItem(
                  icon: Icons.school_outlined,
                  label: 'Cursos',
                  isSelected: isSelected('cursos', '/cursos'),
                  onTap: () {
                    context.push('/cursos'); // Navega a la pantalla de cursos
                  },
                ),
                _MenuItem(
                  icon: Icons.assignment_outlined,
                  label: 'Carga de horas CRM',
                  isSelected: isSelected('cursadas', '/cursadas'),
                  onTap: () {
                    context.push(
                      '/cursadas',
                    ); // Navega a la pantalla de cursadas
                  },
                ),
                _MenuItem(
                  icon: Icons.verified_outlined,
                  label: 'Certificaciones LMS',
                  isSelected: isSelected('certificaciones', '/certificaciones'),
                  onTap: () => context.push('/certificaciones'),
                ),
                /*
                _MenuItem(
                  icon: Icons.analytics_outlined,
                  label: 'Métricas',
                  isSelected: currentRoute.startsWith('/metricas'),
                  onTap: () {
                    context.push(
                      '/metricas',
                    ); // Navega a la pantalla de métricas
                  },
                ),
                */
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Configuración',
                  isSelected: isSelected('configuracion', '/configuracion'),
                  onTap: () {
                    context.push(
                      '/configuracion',
                    ); // Navega a la pantalla de configuración
                  },
                ),
                if (mostrarAdmin)
                  _MenuItem(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Panel de administrador',
                    isSelected: isSelected('admin', '/admin'),
                    onTap: () {
                      context.push('/admin');
                    },
                  ),
              ],
            ),
          ),
          // Logout
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _MenuItem(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              isSelected: false,
              textColor: const Color(0xFFEF4444),
              iconColor: const Color(0xFFEF4444),
              onTap: () async {
                final auth = ref.read(authControllerProvider);
                try {
                  await auth.signOut();
                  if (context.mounted) {
                    context.go(auth.enabled ? '/login' : '/');
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No se pudo completar el cierre de sesión.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular montado sobre el borde de la sidebar. La flecha gira junto
/// con la animación: apunta a la izquierda desplegada y a la derecha oculta.
class _PestanaToggle extends StatefulWidget {
  static const double diametro = 28;

  /// 1 = desplegada, 0 = oculta.
  final double progreso;
  final bool desplegado;
  final VoidCallback onTap;

  const _PestanaToggle({
    required this.progreso,
    required this.desplegado,
    required this.onTap,
  });

  @override
  State<_PestanaToggle> createState() => _PestanaToggleState();
}

class _PestanaToggleState extends State<_PestanaToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mensaje = widget.desplegado ? 'Ocultar menú' : 'Mostrar menú';

    return Tooltip(
      message: mensaje,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            key: const Key('side_menu_toggle'),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _PestanaToggle.diametro,
              height: _PestanaToggle.diametro,
              decoration: BoxDecoration(
                color: _hover ? const Color(0xFFF1F5F9) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: (1 - widget.progreso) * math.pi,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: _hover
                      ? const Color(0xFF0D53C3)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = isSelected
        ? const Color(0xFF0D53C3)
        : const Color(0xFF64748B);
    final bgColor = isSelected
        ? const Color(0xFF0D53C3).withValues(alpha: 0.08)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: onTap,
          dense: true,
          leading: Icon(icon, size: 20, color: iconColor ?? defaultColor),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color:
                  textColor ??
                  (isSelected
                      ? const Color(0xFF0D53C3)
                      : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }
}
