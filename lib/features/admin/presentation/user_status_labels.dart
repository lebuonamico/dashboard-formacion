import 'package:app_finnegans/features/admin/domain/authorized_user.dart';

extension UserStatusLabel on UserStatus {
  String get label => switch (this) {
    UserStatus.active => 'Activo',
    UserStatus.blocked => 'Bloqueado',
    UserStatus.deleted => 'Eliminado',
  };
}
