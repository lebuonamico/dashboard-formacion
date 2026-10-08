import 'package:flutter_riverpod/legacy.dart';

const unauthorizedAccessMessage =
    'Tu cuenta no está autorizada para acceder al sistema. Contactá a un administrador.';

// UI state owned by the app's ProviderScope, independently of authentication.
// Do not autoDispose: navigation and logout must not consume this message.
final accessRejectionMessageProvider = StateProvider<String?>((ref) => null);
