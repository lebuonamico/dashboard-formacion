import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/providers/tema_provider.dart';

/// Usuario logueado en el top bar: foto, nombre y mail. Al hacer clic abre una
/// tarjeta con el detalle de la cuenta, incluido el rol, y el selector de
/// apariencia (sistema, claro u oscuro).
///
/// Cuando la app corre sin Supabase (modo local) no hay sesión, así que cae en
/// la 'U' genérica y en el texto "Modo local".
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final apariencia = ref.watch(temaProvider);
    final cs = context.colorScheme;
    final rol = RolUsuario.fromString(auth.rol);
    final esLider = rol == RolUsuario.lider || rol == RolUsuario.area;
    final datos = _DatosUsuario(
      email: auth.email,
      nombre: auth.nombre,
      fotoUrl: auth.fotoUrl,
      rol: auth.rol,
      modoLocal: !auth.enabled,
      // Lo que lidera (asignado en el panel) y a qué equipo y área pertenece
      // según la nómina: pueden no coincidir, por eso se muestran los dos.
      lidera: esLider
          ? ref
                .watch(estructuraProvider)
                .whenData(
                  (estructura) =>
                      estructura?.lidera(rol: rol, email: auth.email ?? ''),
                )
          : null,
      pertenece: esLider ? ref.watch(empleadoDeSesionProvider) : null,
    );

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Mi cuenta',
      offset: const Offset(0, 52),
      onSelected: ref.read(temaProvider.notifier).cambiar,
      itemBuilder: (_) => [
        PopupMenuItem<ThemeMode>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _TarjetaUsuario(datos: datos),
        ),
        const PopupMenuDivider(),
        for (final opcion in _OpcionApariencia.values)
          _EntradaApariencia(
            key: Key('apariencia_${opcion.modo.name}'),
            opcion: opcion,
            seleccionada: opcion.modo == apariencia,
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FotoUsuario(datos: datos, radio: 18),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    datos.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  if (datos.subtitulo != null)
                    Text(
                      datos.subtitulo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

enum _OpcionApariencia {
  sistema(
    ThemeMode.system,
    'Usar tema del sistema',
    Icons.brightness_auto_outlined,
  ),
  claro(ThemeMode.light, 'Tema claro', Icons.light_mode_outlined),
  oscuro(ThemeMode.dark, 'Tema oscuro', Icons.dark_mode_outlined);

  final ThemeMode modo;
  final String label;
  final IconData icono;

  const _OpcionApariencia(this.modo, this.label, this.icono);
}

/// Opción de apariencia del menú de la cuenta. Es una entrada propia (y no un
/// `PopupMenuItem`) para tener el mismo feedback que los ítems del side menu:
/// sin ripple, con un fondo que se desvanece entre reposo, hover, presionado y
/// seleccionado, y texto e ícono que cambian de color con la misma curva.
class _EntradaApariencia extends PopupMenuEntry<ThemeMode> {
  final _OpcionApariencia opcion;
  final bool seleccionada;

  const _EntradaApariencia({
    super.key,
    required this.opcion,
    required this.seleccionada,
  });

  @override
  double get height => 44;

  @override
  bool represents(ThemeMode? value) => value == opcion.modo;

  @override
  State<_EntradaApariencia> createState() => _EntradaAparienciaState();
}

class _EntradaAparienciaState extends State<_EntradaApariencia> {
  /// Igual que la transición de color de los ítems del side menu.
  static const _duracion = Duration(milliseconds: 200);
  static final _radio = BorderRadius.circular(8);

  bool _hover = false;
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final marca = cs.primary;
    final seleccionada = widget.seleccionada;
    final colorTexto = seleccionada ? marca : cs.onSurface;
    final colorIcono = seleccionada ? marca : cs.onSurfaceVariant;
    final colorFondo = _presionado
        ? marca.withValues(alpha: seleccionada ? 0.14 : 0.1)
        : seleccionada
        ? marca.withValues(alpha: _hover ? 0.11 : 0.08)
        : _hover
        ? cs.onSurface.withValues(alpha: 0.05)
        : cs.onSurface.withValues(alpha: 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerDown: (_) => setState(() => _presionado = true),
          onPointerUp: (_) => setState(() => _presionado = false),
          onPointerCancel: (_) => setState(() => _presionado = false),
          child: AnimatedContainer(
            duration: _duracion,
            curve: Curves.easeOut,
            height: widget.height - 4,
            decoration: BoxDecoration(color: colorFondo, borderRadius: _radio),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: _radio,
                // Sin ripple ni resaltados propios: el feedback lo da el fondo.
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: marca.withValues(alpha: 0.08),
                onTap: () => Navigator.of(context).pop(widget.opcion.modo),
                child: Semantics(
                  selected: seleccionada,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: colorIcono),
                    duration: _duracion,
                    curve: Curves.easeOut,
                    builder: (context, icono, _) =>
                        TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: colorTexto),
                          duration: _duracion,
                          curve: Curves.easeOut,
                          builder: (context, texto, _) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  widget.opcion.icono,
                                  size: 18,
                                  color: icono,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.opcion.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: seleccionada
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: texto,
                                    ),
                                  ),
                                ),
                                AnimatedOpacity(
                                  opacity: seleccionada ? 1 : 0,
                                  duration: _duracion,
                                  curve: Curves.easeOut,
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: texto,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DatosUsuario {
  final String? email;
  final String? nombre;
  final String? fotoUrl;
  final String? rol;
  final bool modoLocal;

  /// Solo para Líder de equipo y Área; `null` para el resto.
  final AsyncValue<String?>? lidera;
  final AsyncValue<Empleado?>? pertenece;

  const _DatosUsuario({
    required this.email,
    required this.nombre,
    required this.fotoUrl,
    required this.rol,
    required this.modoLocal,
    this.lidera,
    this.pertenece,
  });

  /// Primera línea del chip: el nombre si Google lo informa, si no el mail.
  String get titulo =>
      nombre ?? email ?? (modoLocal ? 'Modo local' : 'Sin sesión iniciada');

  /// Segunda línea: el mail, solo cuando no se usó ya como título.
  String? get subtitulo {
    if (nombre != null) return email;
    if (email == null && modoLocal) return 'Sin sesión iniciada';
    return null;
  }

  /// Primera letra del nombre o del mail. Si no hay sesión o viene raro, 'U'.
  String get inicial {
    final limpio = (nombre ?? email)?.trim() ?? '';
    if (limpio.isEmpty) return 'U';
    final inicial = limpio.characters.first.toUpperCase();
    return RegExp(r'[A-ZÁÉÍÓÚÑ0-9]').hasMatch(inicial) ? inicial : 'U';
  }
}

/// Foto de Google recortada en círculo; sin foto, o si no carga, la inicial.
class _FotoUsuario extends StatelessWidget {
  final _DatosUsuario datos;
  final double radio;

  const _FotoUsuario({required this.datos, required this.radio});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final inicial = CircleAvatar(
      radius: radio,
      backgroundColor: cs.primary,
      child: Text(
        datos.inicial,
        style: TextStyle(color: cs.onPrimary, fontSize: radio * 0.85),
      ),
    );
    final url = datos.fotoUrl;
    if (url == null) return inicial;

    return ClipOval(
      child: Image.network(
        url,
        width: radio * 2,
        height: radio * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => inicial,
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  final _DatosUsuario datos;

  const _TarjetaUsuario({required this.datos});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FotoUsuario(datos: datos, radio: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        datos.nombre ??
                            (datos.modoLocal ? 'Modo local' : 'Usuario'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        datos.email ?? 'Sin sesión iniciada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Rol',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            _BadgeRol(rol: datos.rol, modoLocal: datos.modoLocal),
            if (datos.lidera case final lidera?) ...[
              const SizedBox(height: 12),
              _DatoCuenta(
                clave: 'cuenta_lidera',
                titulo: 'Lidera',
                valor: lidera.whenData((texto) => (texto ?? '—', false)),
              ),
            ],
            if (datos.pertenece case final pertenece?) ...[
              const SizedBox(height: 10),
              _DatoCuenta(
                clave: 'cuenta_pertenece',
                titulo: 'Pertenece a',
                valor: pertenece.whenData(
                  (empleado) => (
                    EstructuraOrganizacional.pertenencia(empleado),
                    empleado == null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un dato de la cuenta con su título chico, como el del rol. El valor es el
/// texto y si va en ámbar.
class _DatoCuenta extends StatelessWidget {
  final String clave;
  final String titulo;
  final AsyncValue<(String, bool)> valor;

  const _DatoCuenta({
    required this.clave,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colores = context.colores;
    final (texto, advertencia) = valor.when(
      data: (dato) => dato,
      error: (_, _) => ('No disponible', true),
      loading: () => ('Cargando…', false),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          texto,
          key: Key(clave),
          style: TextStyle(
            fontSize: 13,
            color: advertencia
                ? colores.advertencia.texto
                : colores.textoIntermedio,
          ),
        ),
      ],
    );
  }
}

class _BadgeRol extends StatelessWidget {
  final String? rol;
  final bool modoLocal;

  const _BadgeRol({required this.rol, required this.modoLocal});

  @override
  Widget build(BuildContext context) {
    final conocido = RolUsuario.fromString(rol);
    final crudo = rol?.trim() ?? '';

    final cs = context.colorScheme;
    final advertencia = context.colores.advertencia;

    // Un rol irreconocible se muestra tal cual, en ámbar, como en el panel admin.
    final (texto, color, fondo, descripcion) = conocido != null
        ? (
            conocido.label,
            cs.primary,
            cs.primaryContainer,
            conocido.descripcion,
          )
        : (
            modoLocal ? 'Sin rol' : (crudo.isEmpty ? 'Sin rol' : crudo),
            advertencia.texto,
            advertencia.fondo,
            modoLocal
                ? 'La app corre sin Supabase, no hay usuario autenticado.'
                : 'Rol no reconocido por el sistema.',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          descripcion,
          style: TextStyle(
            fontSize: 12,
            color: context.colores.textoIntermedio,
          ),
        ),
      ],
    );
  }
}
