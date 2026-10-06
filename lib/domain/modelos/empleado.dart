import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';

class Empleado {
  final DateTime? fechaIngreso;
  final String legajo;
  final String nombre;
  final String apellido;
  final Seniority seniority;
  final String area;
  final String mail;
  final String equipo;
  final String gerente;
  final bool activo;

  Empleado({
    this.fechaIngreso,
    required this.legajo,
    required this.nombre,
    required this.apellido,
    required this.seniority,
    required this.area,
    required this.mail,
    this.equipo = '',
    this.gerente = '',
    this.activo = true,
  });

  String get nombreCompleto => '$nombre $apellido';

  Empleado copyWith({
    Seniority? seniority,
    String? area,
    String? equipo,
    String? gerente,
    bool? activo,
  }) => Empleado(
    fechaIngreso: fechaIngreso,
    legajo: legajo,
    nombre: nombre,
    apellido: apellido,
    seniority: seniority ?? this.seniority,
    area: area ?? this.area,
    mail: mail,
    equipo: equipo ?? this.equipo,
    gerente: gerente ?? this.gerente,
    activo: activo ?? this.activo,
  );

  Map<String, dynamic> toJson() => {
    'fechaIngreso': fechaIngreso?.toIso8601String(),
    'legajo': legajo,
    'nombre': nombre,
    'apellido': apellido,
    'seniority': seniority.name,
    'area': area,
    'mail': mail,
    'equipo': equipo,
    'gerente': gerente,
    'activo': activo,
  };

  factory Empleado.fromJson(Map<String, dynamic> json) => Empleado(
    fechaIngreso: json['fechaIngreso'] == null
        ? null
        : fechaObligatoria(json['fechaIngreso'].toString()),
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
    activo: json['activo'] as bool? ?? true,
  );
}
