import 'package:app_finnegans/features/imports/domain/upsert_repository.dart';
import 'dart:convert';

import 'package:app_finnegans/core/legacy/training_mock_data.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockEmployeesRepository implements EmployeesRepository {
  final MockTrainingRepository _source = MockTrainingRepository();

  @override
  Future<List<Employee>> getEmployees({
    String? employeeId,
    String? team,
    String? sector,
  }) async {
    return (await _readEmployees())
        .where(
          (item) =>
              (employeeId == null || item.employeeId == employeeId) &&
              (team == null || item.team == team) &&
              (sector == null || item.area == sector),
        )
        .toList();
  }

  Future<List<Employee>> _readEmployees() => _source.getEmployees();

  @override
  Future<void> replaceEmployees(List<Employee> employees) async {}

  @override
  Future<void> resetToMock() async {}
}

class MockCoursesRepository implements CoursesRepository {
  final MockTrainingRepository _source = MockTrainingRepository();

  @override
  Future<List<Course>> getCourses({String? id, String? name}) async {
    return (await _readCourses())
        .where(
          (item) =>
              (id == null || item.id == id) &&
              (name == null ||
                  item.name.trim().toLowerCase() == name.trim().toLowerCase()),
        )
        .toList();
  }

  Future<List<Course>> _readCourses() => _source.getCourses();

  @override
  Future<void> replaceCourses(List<Course> courses) async {}

  @override
  Future<void> resetToMock() async {}
}

class MockCrmTimeEntriesRepository implements CrmTimeEntriesRepository {
  final MockTrainingRepository _source = MockTrainingRepository();

  @override
  Future<List<CrmTimeEntry>> getTimeEntries({
    String? employeeId,
    String? courseId,
    DateTime? from,
    DateTime? until,
  }) async {
    return (await _readCrmTimeEntry())
        .where(
          (item) =>
              (employeeId == null || item.employeeId == employeeId) &&
              (courseId == null || item.courseId == courseId) &&
              (from == null || !item.date.isBefore(from)) &&
              (until == null || item.date.isBefore(until)),
        )
        .toList();
  }

  Future<List<CrmTimeEntry>> _readCrmTimeEntry() async {
    final courses = await _source.getCourses();
    final legacyEntries = await _source.getLegacyTimeEntries();
    final coursesMap = {for (final course in courses) course.id: course};
    return legacyEntries
        .map(
          (legacyEntry) => CrmTimeEntry(
            id: legacyEntry.id,
            courseId: legacyEntry.courseId,
            courseName: coursesMap[legacyEntry.courseId]?.name ?? '',
            employeeId: legacyEntry.employeeId,
            date: legacyEntry.date,
            hours: coursesMap[legacyEntry.courseId]?.workloadHours ?? 0,
            kind: TimeEntryKind.taken,
          ),
        )
        .toList();
  }

  @override
  Future<void> replaceTimeEntries(List<CrmTimeEntry> timeEntries) async {}

  @override
  Future<void> resetToMock() async {}
}

class LocalEmployeesRepository extends MockEmployeesRepository
    implements UpsertRepository<Employee>, SnapshotRepository<Employee> {
  static const _key = 'formacion_empleados';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<void> upsert(List<Employee> items) async {
    if (items.isEmpty) return;
    final raw = (await _storage).getString(_key);
    final existing = raw == null
        ? <Employee>[]
        : _decodeList(raw, Employee.fromJson);
    final merged = {
      for (final item in [...existing, ...items]) item.employeeId: item,
    };
    await replaceEmployees(merged.values.toList());
  }

  @override
  Future<UpsertResult> syncSnapshotWithResult(List<Employee> items) async {
    if (items.isEmpty || items.any((item) => item.employeeId.trim().isEmpty)) {
      throw const FormatException(
        'La foto de Nómina está vacía o tiene claves inválidas.',
      );
    }
    final raw = (await _storage).getString(_key);
    final previous = raw == null
        ? <Employee>[]
        : _decodeList(raw, Employee.fromJson);
    final current = {for (final item in previous) item.employeeId: item};
    final present = {
      for (final item in items) item.employeeId: item.copyWith(active: true),
    };
    final changes = [
      ...present.values,
      for (final item in previous)
        if (item.isActive && !present.containsKey(item.employeeId))
          item.copyWith(active: false),
    ];
    final inserted = present.keys
        .where((key) => !current.containsKey(key))
        .length;
    final merged = {
      ...current,
      for (final item in changes) item.employeeId: item,
    };
    await replaceEmployees(merged.values.toList());
    return UpsertResult(
      processedRecords: items.length,
      inserted: inserted,
      updated: changes.length - inserted,
    );
  }

  @override
  Future<List<Employee>> _readEmployees() async {
    final raw = (await _storage).getString(_key);
    return raw == null
        ? super._readEmployees()
        : _decodeList(raw, Employee.fromJson);
  }

  @override
  Future<void> replaceEmployees(List<Employee> employees) async {
    await (await _storage).setString(
      _key,
      jsonEncode(employees.map((employee) => employee.toJson()).toList()),
    );
  }

  @override
  Future<void> resetToMock() async {
    await (await _storage).remove(_key);
  }
}

class LocalCoursesRepository extends MockCoursesRepository
    implements UpsertRepository<Course>, SnapshotRepository<Course> {
  static const _key = 'formacion_cursos';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<void> upsert(List<Course> items) async {
    if (items.isEmpty) return;
    final raw = (await _storage).getString(_key);
    final existing = raw == null
        ? <Course>[]
        : _decodeList(raw, Course.fromJson);
    final merged = {
      for (final item in [...existing, ...items]) item.id: item,
    };
    await replaceCourses(merged.values.toList());
  }

  @override
  Future<UpsertResult> syncSnapshotWithResult(List<Course> items) async {
    if (items.isEmpty || items.any((item) => item.id.trim().isEmpty)) {
      throw const FormatException(
        'La foto de Cursos está vacía o tiene claves inválidas.',
      );
    }
    final raw = (await _storage).getString(_key);
    final previous = raw == null
        ? <Course>[]
        : _decodeList(raw, Course.fromJson);
    final current = {for (final item in previous) item.id: item};
    final present = {
      for (final item in items) item.id: item.copyWith(active: true),
    };
    final changes = [
      ...present.values,
      for (final item in previous)
        if (item.isActive && !present.containsKey(item.id))
          item.copyWith(active: false),
    ];
    final inserted = present.keys
        .where((key) => !current.containsKey(key))
        .length;
    final merged = {...current, for (final item in changes) item.id: item};
    await replaceCourses(merged.values.toList());
    return UpsertResult(
      processedRecords: items.length,
      inserted: inserted,
      updated: changes.length - inserted,
    );
  }

  @override
  Future<List<Course>> _readCourses() async {
    final raw = (await _storage).getString(_key);
    return raw == null
        ? super._readCourses()
        : _decodeList(raw, Course.fromJson);
  }

  @override
  Future<void> replaceCourses(List<Course> courses) async {
    await (await _storage).setString(
      _key,
      jsonEncode(courses.map((course) => course.toJson()).toList()),
    );
  }

  @override
  Future<void> resetToMock() async {
    await (await _storage).remove(_key);
  }
}

class LocalCrmTimeEntriesRepository extends MockCrmTimeEntriesRepository
    implements UpsertRepository<CrmTimeEntry> {
  static const _key = 'formacion_carga_de_horas_crm';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<void> upsert(List<CrmTimeEntry> items) async {
    if (items.isEmpty) return;
    final raw = (await _storage).getString(_key);
    final existing = raw == null
        ? <CrmTimeEntry>[]
        : _decodeList(raw, CrmTimeEntry.fromJson);
    final merged = {
      for (final item in [...existing, ...items]) item.id: item,
    };
    await replaceTimeEntries(merged.values.toList());
  }

  @override
  Future<List<CrmTimeEntry>> _readCrmTimeEntry() async {
    final raw = (await _storage).getString(_key);
    if (raw == null) return super._readCrmTimeEntry();

    final timeEntries = _decodeList(raw, CrmTimeEntry.fromJson);
    if (timeEntries.isEmpty ||
        timeEntries.every((timeEntry) => timeEntry.courseName.isNotEmpty)) {
      return timeEntries;
    }

    try {
      final records = jsonDecode(raw) as List<dynamic>;
      final courses = await LocalCoursesRepository().getCourses();
      final coursesById = {for (final course in courses) course.id: course};
      final migratedTimeEntries = records.map((record) {
        final data = Map<String, dynamic>.from(record as Map);
        if ((data['cursoNombre']?.toString().trim() ?? '').isEmpty) {
          final courseId = data['cursoId']?.toString();
          data['cursoNombre'] = coursesById[courseId]?.name ?? '';
        }
        return CrmTimeEntry.fromJson(data);
      }).toList();
      await replaceTimeEntries(migratedTimeEntries);
      return migratedTimeEntries;
    } on FormatException {
      return timeEntries;
    } on TypeError {
      return timeEntries;
    }
  }

  @override
  Future<void> replaceTimeEntries(List<CrmTimeEntry> timeEntries) async {
    await (await _storage).setString(
      _key,
      jsonEncode(timeEntries.map((timeEntry) => timeEntry.toJson()).toList()),
    );
  }

  @override
  Future<void> resetToMock() async {
    await (await _storage).remove(_key);
  }
}

class MockLmsCertificationsRepository implements LmsCertificationsRepository {
  @override
  Future<List<LmsCertification>> getCertifications({
    String? employeeId,
    String? courseId,
  }) async {
    return (await _readLmsCertifications())
        .where(
          (item) =>
              (employeeId == null || item.employeeId == employeeId) &&
              (courseId == null || item.courseId == courseId),
        )
        .toList();
  }

  Future<List<LmsCertification>> _readLmsCertifications() async => [];

  @override
  Future<void> replaceCertifications(
    List<LmsCertification> certifications,
  ) async {}
}

class LocalLmsCertificationsRepository extends MockLmsCertificationsRepository
    implements UpsertRepository<LmsCertification> {
  static const _key = 'formacion_certificaciones_moodle';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<void> upsert(List<LmsCertification> items) async {
    if (items.isEmpty) return;
    final raw = (await _storage).getString(_key);
    final existing = raw == null
        ? <LmsCertification>[]
        : _decodeList(raw, LmsCertification.fromJson);
    // Corrections replace the explicit employee/course state; absent pairs remain.
    final records = [...existing, ...items];
    final idsByName = certificationCourseIds(records);
    final rows = {
      for (final item in records) lmsCertificationKey(item, idsByName): item,
    };
    await replaceCertifications(rows.values.toList());
  }

  @override
  Future<List<LmsCertification>> _readLmsCertifications() async {
    final raw = (await _storage).getString(_key);
    return raw == null
        ? super._readLmsCertifications()
        : _decodeList(raw, LmsCertification.fromJson);
  }

  @override
  Future<void> replaceCertifications(
    List<LmsCertification> certifications,
  ) async {
    await (await _storage).setString(
      _key,
      jsonEncode(certifications.map((item) => item.toJson()).toList()),
    );
  }
}

/// Sin versiones guardadas rige el plan por defecto de cada seniority.
class LocalTrainingPlanRepository implements TrainingPlanRepository {
  static const _key = 'formacion_plan_formacion';

  Future<SharedPreferences> get _storage => SharedPreferences.getInstance();

  @override
  Future<TrainingPlanHistory> getPlans() async {
    final raw = (await _storage).getString(_key);
    if (raw == null) return const TrainingPlanHistory.empty();
    return TrainingPlanHistory(_decodeList(raw, TrainingPlanVersion.fromJson));
  }

  @override
  Future<void> saveVersion(TrainingPlanVersion version) async {
    final plans = (await getPlans()).withVersion(version);
    await (await _storage).setString(
      _key,
      jsonEncode(plans.versions.map((item) => item.toJson()).toList()),
    );
  }
}

List<T> _decodeList<T>(String raw, T Function(Map<String, dynamic>) fromJson) {
  try {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  } on TypeError {
    throw const FormatException('Datos locales con estructura inválida.');
  }
}
