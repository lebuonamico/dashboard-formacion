import 'dart:convert';

import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/admin/data/in_memory_authorized_users_repository.dart';
import 'package:app_finnegans/features/certifications/data/in_memory_lms_certifications_repository.dart';
import 'package:app_finnegans/features/certifications/data/lms_certifications_seed.dart';
import 'package:app_finnegans/features/certifications/data/supabase_lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/data/courses_seed.dart';
import 'package:app_finnegans/features/courses/data/in_memory_courses_repository.dart';
import 'package:app_finnegans/features/courses/data/supabase_courses_repository.dart';
import 'package:app_finnegans/features/employees/data/employees_seed.dart';
import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/features/employees/data/supabase_employees_repository.dart';
import 'package:app_finnegans/features/time_entries/data/crm_time_entries_seed.dart';
import 'package:app_finnegans/features/time_entries/data/in_memory_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/time_entries/data/supabase_crm_time_entries_repository.dart';
import 'package:app_finnegans/features/admin/data/supabase_authorized_users_repository.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_repository_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_repository_provider.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/crm_time_entries_repository_provider.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/lms_certifications_repository_provider.dart';
import 'package:app_finnegans/features/admin/presentation/providers/authorized_users_repository_provider.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ProviderContainer _remoteContainer(SupabaseClient client) => ProviderContainer(
  overrides: [
    supabaseClientProvider.overrideWithValue(client),
    // These tests cover repository errors, not scope: an administrator sees
    // everything, so hours and completions do not depend on the payroll.
    sessionDataProvider.overrideWithValue((
      enabled: true,
      email: 'admin@finnegans.com',
      role: 'admin',
    )),
  ],
  // Disable Riverpod's retries so each request has one deterministic result.
  retry: (_, _) => null,
);

void _expectRemoteRepositories(ProviderContainer container) {
  expect(
    container.read(employeesRepositoryProvider),
    isA<SupabaseEmployeesRepository>(),
  );
  expect(
    container.read(coursesRepositoryProvider),
    isA<SupabaseCoursesRepository>(),
  );
  expect(
    container.read(crmTimeEntriesRepositoryProvider),
    isA<SupabaseCrmTimeEntriesRepository>(),
  );
  expect(
    container.read(lmsCertificationsRepositoryProvider),
    isA<SupabaseLmsCertificationsRepository>(),
  );
  expect(
    container.read(authorizedUsersRepositoryProvider),
    isA<SupabaseAuthorizedUsersRepository>(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'USE_SUPABASE=false selects in-memory repositories without a client',
    () async {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith(
            (ref) => throw StateError('El modo local no debe crear Supabase'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(employeesRepositoryProvider),
        isA<InMemoryEmployeesRepository>(),
      );
      expect(
        container.read(coursesRepositoryProvider),
        isA<InMemoryCoursesRepository>(),
      );
      expect(
        container.read(crmTimeEntriesRepositoryProvider),
        isA<InMemoryCrmTimeEntriesRepository>(),
      );
      expect(
        container.read(lmsCertificationsRepositoryProvider),
        isA<InMemoryLmsCertificationsRepository>(),
      );
      expect(
        container.read(authorizedUsersRepositoryProvider),
        isA<InMemoryAuthorizedUsersRepository>(),
      );
      expect(
        await container.read(employeesProvider.future),
        hasLength(employeesSeed.length),
      );
      expect(
        await container.read(coursesProvider.future),
        hasLength(coursesSeed.length),
      );
      expect(
        await container.read(crmTimeEntriesProvider.future),
        hasLength(crmTimeEntriesSeed.length),
      );
      expect(
        await container.read(lmsCertificationsProvider.future),
        hasLength(lmsCertificationsSeed.length),
      );
    },
    skip: SupabaseConfig.enabled,
  );

  group('USE_SUPABASE=true makes Supabase the only active data source', () {
    for (final status in [403, 500]) {
      test(
        'All repositories and data providers propagate HTTP $status despite local data',
        () async {
          final requests = <http.Request>[];
          final code = status == 403 ? '42501' : 'XX000';
          final client = SupabaseClient(
            'https://test.supabase.co',
            'public-test-key',
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode({'message': 'remote failure', 'code': code}),
                status,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }),
          );
          addTearDown(client.dispose);
          final container = _remoteContainer(client);
          addTearDown(container.dispose);
          _expectRemoteRepositories(container);
          final failure = throwsA(
            isA<PostgrestException>()
                .having((error) => error.code, 'code', code)
                .having((error) => error.message, 'message', 'remote failure'),
          );

          await expectLater(
            container.read(employeesRepositoryProvider).getEmployees(),
            failure,
          );
          await expectLater(
            container.read(coursesRepositoryProvider).getCourses(),
            failure,
          );
          await expectLater(
            container.read(crmTimeEntriesRepositoryProvider).getTimeEntries(),
            failure,
          );
          await expectLater(
            container
                .read(lmsCertificationsRepositoryProvider)
                .getCertifications(),
            failure,
          );
          await expectLater(container.read(employeesProvider.future), failure);
          await expectLater(container.read(coursesProvider.future), failure);
          await expectLater(
            container.read(crmTimeEntriesProvider.future),
            failure,
          );
          await expectLater(
            container.read(lmsCertificationsProvider.future),
            failure,
          );
          expect(container.read(employeesProvider).hasError, isTrue);
          expect(container.read(coursesProvider).hasError, isTrue);
          expect(container.read(crmTimeEntriesProvider).hasError, isTrue);
          expect(container.read(lmsCertificationsProvider).hasError, isTrue);
          expect(requests.map((request) => request.url.path).toSet(), {
            '/rest/v1/empleados',
            '/rest/v1/cursos',
            '/rest/v1/horas_capacitacion',
            '/rest/v1/finalizaciones_cursos',
          });
          expect(requests.every((request) => request.method == 'GET'), isTrue);
        },
      );
    }

    test(
      'Empty remote tables remain empty despite the in-memory seed',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-test-key',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {
                'content-type': 'application/json',
                'content-range': '*/0',
              },
            );
          }),
        );
        addTearDown(client.dispose);
        final container = _remoteContainer(client);
        addTearDown(container.dispose);
        _expectRemoteRepositories(container);

        expect(await container.read(employeesProvider.future), isEmpty);
        expect(await container.read(coursesProvider.future), isEmpty);
        expect(await container.read(crmTimeEntriesProvider.future), isEmpty);
        expect(await container.read(lmsCertificationsProvider.future), isEmpty);
        expect(requests.length, 4);
      },
    );

    test('Reads select the physical columns of each table', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {
              'content-type': 'application/json',
              'content-range': '*/0',
            },
          );
        }),
      );
      addTearDown(client.dispose);
      final container = _remoteContainer(client);
      addTearDown(container.dispose);

      await container.read(employeesRepositoryProvider).getEmployees();
      await container.read(coursesRepositoryProvider).getCourses();
      await container.read(crmTimeEntriesRepositoryProvider).getTimeEntries();
      await container
          .read(lmsCertificationsRepositoryProvider)
          .getCertifications();

      final selectByTable = {
        for (final request in requests)
          request.url.pathSegments.last: request.url.queryParameters['select'],
      };
      expect(selectByTable, {
        'empleados': SupabaseEmployeesRepository.mapping.columns.values.join(
          ',',
        ),
        'cursos': SupabaseCoursesRepository.mapping.columns.values.join(','),
        'horas_capacitacion': SupabaseCrmTimeEntriesRepository
            .mapping
            .columns
            .values
            .join(','),
        'finalizaciones_cursos': SupabaseLmsCertificationsRepository
            .mapping
            .columns
            .values
            .join(','),
      });
    });

    test('Course view models preserve auxiliary employee errors', () async {
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: MockClient((request) async {
          final denied = request.url.path.endsWith('/empleados');
          return http.Response(
            denied ? '{"message":"employees denied","code":"42501"}' : '[]',
            denied ? 403 : 200,
            request: request,
            headers: {
              'content-type': 'application/json',
              'content-range': '*/0',
            },
          );
        }),
      );
      addTearDown(client.dispose);
      final container = _remoteContainer(client);
      addTearDown(container.dispose);

      expect(container.read(courseStatsProvider).isLoading, isTrue);
      await expectLater(
        container.read(employeesProvider.future),
        throwsA(isA<PostgrestException>()),
      );
      expect(await container.read(coursesProvider.future), isEmpty);
      await container.pump();

      final state = container.read(courseStatsProvider);
      expect(state.hasError, isTrue);
      expect(
        state.error,
        isA<PostgrestException>().having(
          (error) => error.message,
          'message',
          'employees denied',
        ),
      );
    });

    for (final table in ['empleados', 'cursos']) {
      test('Hours view models preserve auxiliary $table errors', () async {
        final client = SupabaseClient(
          'https://test.supabase.co',
          'public-test-key',
          httpClient: MockClient((request) async {
            final denied = request.url.path.endsWith('/$table');
            return http.Response(
              denied
                  ? jsonEncode({'message': '$table denied', 'code': '42501'})
                  : '[]',
              denied ? 403 : 200,
              request: request,
              headers: {
                'content-type': 'application/json',
                'content-range': '*/0',
              },
            );
          }),
        );
        addTearDown(client.dispose);
        final container = _remoteContainer(client);
        addTearDown(container.dispose);

        expect(container.read(joinedTimeEntriesProvider).isLoading, isTrue);
        if (table == 'empleados') {
          await expectLater(
            container.read(employeesProvider.future),
            throwsA(isA<PostgrestException>()),
          );
          expect(await container.read(coursesProvider.future), isEmpty);
        } else {
          await expectLater(
            container.read(coursesProvider.future),
            throwsA(isA<PostgrestException>()),
          );
          expect(await container.read(employeesProvider.future), isEmpty);
        }
        expect(await container.read(crmTimeEntriesProvider.future), isEmpty);
        await expectLater(
          container.read(joinedTimeEntriesProvider.future),
          throwsA(
            isA<PostgrestException>().having(
              (error) => error.message,
              'message',
              '$table denied',
            ),
          ),
        );
        expect(container.read(joinedTimeEntriesProvider).hasError, isTrue);
      });
    }
  }, skip: !SupabaseConfig.enabled);
}
