import 'access_rejection_storage_stub.dart'
    if (dart.library.js_interop) 'access_rejection_storage_web.dart'
    as storage;

const unauthorizedAccessMessage =
    'Tu cuenta no está autorizada para acceder al sistema. Contactá a un administrador.';

void rememberUnauthorizedAccess() =>
    storage.writeRejectionReason('unauthorized');

String? readAccessRejectionMessage() =>
    storage.readRejectionReason() == 'unauthorized'
    ? unauthorizedAccessMessage
    : null;

String? consumeAccessRejectionMessage() =>
    storage.takeRejectionReason() == 'unauthorized'
    ? unauthorizedAccessMessage
    : null;

void clearAccessRejection() => storage.clearRejectionReason();
