import 'package:app_finnegans/core/config/supabase_client_provider.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/features/employees/data/in_memory_employees_repository.dart';
import 'package:app_finnegans/features/employees/data/supabase_employee_history_repository.dart';
import 'package:app_finnegans/features/employees/data/supabase_employees_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_repository.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In memory, the payroll and its history are one instance: the upsert is
/// what writes the history, as the database trigger does.
final _inMemoryEmployeesProvider = Provider<InMemoryEmployeesRepository>(
  (ref) => InMemoryEmployeesRepository(),
);

final employeesRepositoryProvider = Provider<EmployeesRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseEmployeesRepository(ref.watch(supabaseClientProvider))
      : ref.watch(_inMemoryEmployeesProvider),
);

final employeeHistoryRepositoryProvider = Provider<EmployeeHistoryRepository>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseEmployeeHistoryRepository(ref.watch(supabaseClientProvider))
      : ref.watch(_inMemoryEmployeesProvider),
);
