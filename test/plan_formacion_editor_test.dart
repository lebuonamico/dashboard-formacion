import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/plan_formacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/repositorios/plan_formacion_repository.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/widgets/configuracion/plan_formacion_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PlanFake implements PlanFormacionRepository {
  PlanesFormacion planes;
  final guardadas = <VersionPlanFormacion>[];

  _PlanFake([this.planes = const PlanesFormacion.sinVersiones()]);

  @override
  Future<PlanesFormacion> getPlanes() async => planes;

  @override
  Future<void> guardarVersion(VersionPlanFormacion version) async {
    guardadas.add(version);
    planes = planes.conVersion(version);
  }
}

Future<ProviderContainer> _mostrarEditor(
  WidgetTester tester,
  _PlanFake repositorio,
) async {
  tester.view.physicalSize = const Size(1400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [planFormacionRepositoryProvider.overrideWithValue(repositorio)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: PlanFormacionEditor()),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return container;
}

Finder _campo(Seniority seniority, TipoCurso tipo) =>
    find.byKey(Key('plan_${seniority.name}_${tipo.name}'));

String _total(WidgetTester tester, Seniority seniority) =>
    tester.widget<Text>(find.byKey(Key('plan_total_${seniority.name}'))).data!;

bool _puedeGuardar(WidgetTester tester) =>
    tester
        .widget<ButtonStyleButton>(find.byKey(const Key('plan_guardar')))
        .onPressed !=
    null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Pasa Junior 1 a 6 h de negocio y 2 de blandas y lo guarda', (
    tester,
  ) async {
    final repositorio = _PlanFake();
    final container = await _mostrarEditor(tester, repositorio);

    expect(_total(tester, Seniority.junior1), '8 h');
    expect(_puedeGuardar(tester), isFalse);

    await tester.enterText(
      _campo(Seniority.junior1, TipoCurso.habilidadesDeNegocio),
      '6',
    );
    await tester.enterText(
      _campo(Seniority.junior1, TipoCurso.habilidadesBlandas),
      '2',
    );
    await tester.pump();

    expect(_total(tester, Seniority.junior1), '8 h');
    expect(_puedeGuardar(tester), isTrue);

    await tester.tap(find.byKey(const Key('plan_guardar')));
    await tester.pumpAndSettle();

    final hoy = DateTime.now();
    final guardada = repositorio.guardadas.single;
    expect(guardada.vigenteDesde, DateTime(hoy.year, hoy.month));
    expect(guardada.plan.horasRequeridas(Seniority.junior1), {
      TipoCurso.habilidadesDeNegocio: 6,
      TipoCurso.habilidadesBlandas: 2,
      TipoCurso.libresExploracion: 0,
      TipoCurso.dictadoCapacitaciones: 0,
    });
    // El resto queda como estaba.
    expect(
      guardada.plan.horasRequeridas(Seniority.senior2),
      Seniority.senior2.planFormacion,
    );
    expect(find.textContaining('Plan guardado: rige desde'), findsOneWidget);
    // El plan guardado es la nueva base: no quedan cambios pendientes.
    expect(_puedeGuardar(tester), isFalse);
    // Y el cálculo de cumplimiento ya lo usa.
    final servicio = await container.read(cumplimientoServiceProvider.future);
    expect(servicio.planes.vigenteEn(hoy.year, hoy.month), guardada.plan);
  });

  testWidgets('El total es libre y acepta coma decimal', (tester) async {
    await _mostrarEditor(tester, _PlanFake());

    await tester.enterText(
      _campo(Seniority.trainee, TipoCurso.habilidadesDeNegocio),
      '5,5',
    );
    await tester.pump();

    expect(_total(tester, Seniority.trainee), '9,5 h');
    expect(_puedeGuardar(tester), isTrue);
  });

  testWidgets('Un valor inválido marca el campo y no deja guardar', (
    tester,
  ) async {
    final repositorio = _PlanFake();
    await _mostrarEditor(tester, repositorio);

    await tester.enterText(
      _campo(Seniority.manager, TipoCurso.libresExploracion),
      '-2',
    );
    await tester.pump();

    expect(find.text('No puede ser negativo'), findsOneWidget);
    expect(_total(tester, Seniority.manager), '—');
    expect(_puedeGuardar(tester), isFalse);

    await tester.enterText(
      _campo(Seniority.manager, TipoCurso.libresExploracion),
      'ocho',
    );
    await tester.pump();
    expect(find.text('Ingresá un número'), findsOneWidget);
    expect(_puedeGuardar(tester), isFalse);
    expect(repositorio.guardadas, isEmpty);
  });

  testWidgets('Restaurar trae los valores por defecto sin guardar', (
    tester,
  ) async {
    final hoy = DateTime.now();
    final cambiado = PlanFormacion({
      for (final seniority in Seniority.values)
        seniority: seniority == Seniority.junior1
            ? {
                TipoCurso.habilidadesDeNegocio: 6,
                TipoCurso.habilidadesBlandas: 2,
                TipoCurso.libresExploracion: 0,
                TipoCurso.dictadoCapacitaciones: 0,
              }
            : seniority.planFormacion,
    });
    final repositorio = _PlanFake(
      PlanesFormacion([
        VersionPlanFormacion(
          vigenteDesde: DateTime(hoy.year, hoy.month),
          plan: cambiado,
        ),
      ]),
    );
    await _mostrarEditor(tester, repositorio);

    // Arranca con la versión guardada del mes actual.
    expect(
      tester
          .widget<TextField>(
            _campo(Seniority.junior1, TipoCurso.habilidadesDeNegocio),
          )
          .controller!
          .text,
      '6',
    );
    expect(
      find.text('Estás editando la versión que rige desde ese mes.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('plan_restaurar')));
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            _campo(Seniority.junior1, TipoCurso.habilidadesDeNegocio),
          )
          .controller!
          .text,
      '4',
    );
    expect(_puedeGuardar(tester), isTrue);
    expect(repositorio.guardadas, isEmpty);

    await tester.tap(find.byKey(const Key('plan_descartar')));
    await tester.pump();
    expect(_puedeGuardar(tester), isFalse);
  });
}
