import 'package:app_finnegans/domain/modelos/seniority.dart';

class Empleado {
  final String legajo;
  final String nombre;
  final String apellido;
  final Seniority seniority;
  final String area;
  final String mail;
  final String equipo;
  final String gerente;

  Empleado({
    required this.legajo,
    required this.nombre,
    required this.apellido,
    required this.seniority,
    required this.area,
    required this.mail,
    this.equipo = '',
    this.gerente = '',
  });

  String get nombreCompleto => '$nombre $apellido';

  Map<String, dynamic> toJson() => {
        'legajo': legajo,
        'nombre': nombre,
        'apellido': apellido,
        'seniority': seniority.name,
        'area': area,
        'mail': mail,
        'equipo': equipo,
        'gerente': gerente,
      };

  factory Empleado.fromJson(Map<String, dynamic> json) => Empleado(
        legajo: json['legajo']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        apellido: json['apellido']?.toString() ?? '',
        seniority: Seniority.values.firstWhere(
          (s) => s.name == json['seniority'],
          orElse: () => Seniority.fromString(json['seniority']?.toString() ?? ''),
        ),
        area: json['area']?.toString() ?? '',
        mail: json['mail']?.toString() ?? '',
        equipo: json['equipo']?.toString() ?? '',
        gerente: json['gerente']?.toString() ?? '',
      );
}