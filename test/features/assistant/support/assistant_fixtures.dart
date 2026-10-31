import 'package:app_finnegans/core/period/presentation/period_filter_provider.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_context.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const origin =
    'Datos ficticios de demostración cargados en el proyecto académico';

/// The in-memory seed, seen from [month] of 2026.
ProviderContainer seedContainer({
  int month = 7,
  PeriodScope scope = PeriodScope.monthly,
  bool dynamicContext = true,
}) {
  final container = ProviderContainer(
    overrides: [
      periodFilterProvider.overrideWith(
        () => PeriodFilterNotifier(
          PeriodFilter(scope: scope, month: month, year: 2026),
        ),
      ),
      aiRealContextProvider.overrideWithValue(dynamicContext),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// What the chat does when sending: plan the question with the visible
/// period and build its context with the session's data.
Future<AssistantContext> contextFor(
  ProviderContainer container,
  AssistantDestination destination,
  String question,
) {
  final query = container
      .read(assistantQueryPlannerProvider)
      .plan(question, destination, container.read(periodFilterProvider));
  return container
      .read(assistantContextBuilderProvider)
      .build(
        query,
        dynamic: container.read(aiRealContextProvider),
        loadData: () => container.read(assistantDataProvider.future),
      );
}
