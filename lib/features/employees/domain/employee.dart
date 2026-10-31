import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';

class Employee {
  final DateTime? hireDate;
  final String employeeId;
  final String firstName;
  final String lastName;
  final Seniority seniority;
  final String area;
  final String email;
  final String team;
  final String manager;
  final bool isActive;

  Employee({
    this.hireDate,
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.seniority,
    required this.area,
    required this.email,
    this.team = '',
    this.manager = '',
    this.isActive = true,
  });

  Employee copyWith({
    DateTime? hireDate,
    String? employeeId,
    String? firstName,
    String? lastName,
    Seniority? seniority,
    String? area,
    String? email,
    String? team,
    String? manager,
    bool? isActive,
  }) => Employee(
    hireDate: hireDate ?? this.hireDate,
    employeeId: employeeId ?? this.employeeId,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    seniority: seniority ?? this.seniority,
    area: area ?? this.area,
    email: email ?? this.email,
    team: team ?? this.team,
    manager: manager ?? this.manager,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'hireDate': hireDate?.toIso8601String(),
    'employeeId': employeeId,
    'firstName': firstName,
    'lastName': lastName,
    'seniority': seniority.name,
    'area': area,
    'email': email,
    'team': team,
    'manager': manager,
    'isActive': isActive,
  };

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    hireDate: json['hireDate'] == null
        ? null
        : requiredDate(json['hireDate'].toString()),
    employeeId: json['employeeId']?.toString() ?? '',
    firstName: json['firstName']?.toString() ?? '',
    lastName: json['lastName']?.toString() ?? '',
    seniority:
        Seniority.values.asNameMap()[json['seniority']] ??
        (throw FormatException(
          'Seniority desconocido: "${json['seniority']}".',
        )),
    area: json['area']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    team: json['team']?.toString() ?? '',
    manager: json['manager']?.toString() ?? '',
    isActive: json['isActive'] as bool? ?? true,
  );
}
