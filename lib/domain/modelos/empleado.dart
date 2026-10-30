import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';

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

  String get fullName => '$firstName $lastName';

  /// El empleado de la nómina con ese mail, comparado sin espacios ni
  /// mayúsculas. Si hubiera dos filas, prefiere la activa.
  static Employee? byEmail(Iterable<Employee> employees, String? email) {
    final searched = email?.trim().toLowerCase() ?? '';
    if (searched.isEmpty) return null;
    Employee? found;
    for (final employee in employees) {
      if (employee.email.trim().toLowerCase() != searched) continue;
      if (employee.isActive) return employee;
      found ??= employee;
    }
    return found;
  }

  Employee copyWith({
    Seniority? seniority,
    String? area,
    String? team,
    String? manager,
    bool? active,
  }) => Employee(
    hireDate: hireDate,
    employeeId: employeeId,
    firstName: firstName,
    lastName: lastName,
    seniority: seniority ?? this.seniority,
    area: area ?? this.area,
    email: email,
    team: team ?? this.team,
    manager: manager ?? this.manager,
    isActive: active ?? isActive,
  );

  Map<String, dynamic> toJson() => {
    'fechaIngreso': hireDate?.toIso8601String(),
    'legajo': employeeId,
    'nombre': firstName,
    'apellido': lastName,
    'seniority': seniority.name,
    'area': area,
    'mail': email,
    'equipo': team,
    'gerente': manager,
    'activo': isActive,
  };

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    hireDate: json['fechaIngreso'] == null
        ? null
        : requiredDate(json['fechaIngreso'].toString()),
    employeeId: json['legajo']?.toString() ?? '',
    firstName: json['nombre']?.toString() ?? '',
    lastName: json['apellido']?.toString() ?? '',
    seniority: Seniority.values.firstWhere(
      (s) => s.name == json['seniority'],
      orElse: () => Seniority.fromString(json['seniority']?.toString() ?? ''),
    ),
    area: json['area']?.toString() ?? '',
    email: json['mail']?.toString() ?? '',
    team: json['equipo']?.toString() ?? '',
    manager: json['gerente']?.toString() ?? '',
    isActive: json['activo'] as bool? ?? true,
  );
}
