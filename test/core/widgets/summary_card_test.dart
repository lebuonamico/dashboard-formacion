import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/summary_card/count_badge.dart';
import 'package:app_finnegans/core/widgets/summary_card/status_badge.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card_footer.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_card_header.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_info_row.dart';
import 'package:app_finnegans/core/widgets/summary_card/summary_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _colors = ColorPair(Color(0xFF15803D), Color(0xFFDCFCE7));

Future<void> _show(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, height: 260, child: child)),
    ),
  ),
);

Widget _card({
  double? deviation,
  VoidCallback? onTap,
  double percentage = 75,
}) => SummaryCard(
  colors: _colors,
  onTap: onTap ?? () {},
  header: const SummaryCardHeader(
    title: 'Core',
    subtitle: 'Desarrollo',
    badge: StatusBadge(label: 'En objetivo', colors: _colors),
  ),
  details: const [
    SummaryInfoRow(icon: Icons.person_outline, text: 'Líder: Ana'),
  ],
  progress: SummaryProgress(
    caption: '1 de 2 en objetivo',
    percentage: percentage,
    colors: _colors,
    help: 'Ayuda',
  ),
  footer: SummaryCardFooter(
    completedHours: 12,
    targetHours: 16,
    deviation: deviation,
    actionLabel: 'Ver detalle',
  ),
);

void main() {
  testWidgets('Muestra encabezado, detalle, progreso y pie', (tester) async {
    await _show(tester, _card(deviation: -4));

    expect(find.text('Core'), findsOne);
    expect(find.text('Desarrollo'), findsOne);
    expect(find.text('Líder: Ana'), findsOne);
    expect(find.text('1 de 2 en objetivo'), findsOne);
    expect(find.text('75%'), findsOne);
    expect(find.text('12.0 de 16.0 hs'), findsOne);
    expect(find.text('Ver detalle'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El badge usa el color del estado', (tester) async {
    await _show(tester, _card());

    final label = tester.widget<Text>(find.text('En objetivo'));
    expect(label.style?.color, _colors.text);
  });

  testWidgets('El desvío negativo va en rojo y el positivo en verde', (
    tester,
  ) async {
    await _show(tester, _card(deviation: -4));
    final colors = AppTheme.light().extension<AppColors>()!;
    expect(
      tester.widget<Text>(find.text('-4.0 hs')).style?.color,
      colors.danger.text,
    );

    await _show(tester, _card(deviation: 2));
    expect(
      tester.widget<Text>(find.text('+2.0 hs')).style?.color,
      colors.success.text,
    );
  });

  testWidgets('Sin desvío no lo muestra', (tester) async {
    await _show(tester, _card());

    expect(find.textContaining('hs', findRichText: true), findsOne);
  });

  testWidgets('El progreso se topea en 100 %', (tester) async {
    await _show(tester, _card(percentage: 150));

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1);
  });

  testWidgets('Tocar la tarjeta llama a onTap', (tester) async {
    var taps = 0;
    await _show(tester, _card(onTap: () => taps++));

    await tester.tap(find.text('Core'));
    expect(taps, 1);
  });

  testWidgets('El contador muestra el número', (tester) async {
    await _show(tester, const CountBadge(count: 7));

    expect(find.text('7'), findsOne);
  });
}
