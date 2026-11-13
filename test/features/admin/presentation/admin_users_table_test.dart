import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/presentation/widgets/admin_users_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<AuthorizedUser> _users({String? blocked}) => [
  for (var i = 1; i <= 10; i++)
    AuthorizedUser(
      email: 'usuario$i@finnegans-demo.com',
      role: 'academia',
      isActive: 'usuario$i@finnegans-demo.com' != blocked,
      blockedAt: 'usuario$i@finnegans-demo.com' == blocked
          ? DateTime(2026, 11)
          : null,
    ),
];

Widget _table(List<AuthorizedUser> users) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: AdminUsersTable(
        users: users,
        selectedEmail: null,
        ownEmail: null,
        onSelect: (_) {},
      ),
    ),
  ),
);

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.textScaleFactorTestValue = 0.5;
  });

  testWidgets('Una acción sobre un usuario no vuelve a la primera página', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(3200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .clearTextScaleFactorTestValue,
    );

    await tester.pumpWidget(_table(_users()));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('usuario9@finnegans-demo.com'), findsOne);

    // Bloquear a usuario9 arma una lista nueva con los mismos usuarios.
    await tester.pumpWidget(
      _table(_users(blocked: 'usuario9@finnegans-demo.com')),
    );
    await tester.pumpAndSettle();
    expect(find.text('usuario9@finnegans-demo.com'), findsOne);

    // Otro conjunto de usuarios (un filtro) sí vuelve a la primera.
    await tester.pumpWidget(_table(_users().reversed.toList()));
    await tester.pumpAndSettle();
    expect(find.text('usuario10@finnegans-demo.com'), findsOne);
    expect(find.text('usuario2@finnegans-demo.com'), findsNothing);
  });
}
