import 'package:flutter_riverpod/legacy.dart';

/// Si la sidebar está desplegada. Cada pantalla monta su propio `SideMenu`,
/// así que el estado vive acá para sobrevivir a la navegación. Arranca
/// desplegada y no se persiste: al recargar la página vuelve a desplegarse.
final sideMenuDesplegadoProvider = StateProvider<bool>((ref) => true);
