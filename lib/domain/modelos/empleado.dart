import 'package:app_finnegans/domain/modelos/seniority.dart';

class Empleado {
  final String legajo;
  final String nombre;
  final String apellido;
  final String puesto;
  final Seniority seniority;
  final String area;
  final String mail;

  Empleado({
    required this.legajo,
    required this.nombre,
    required this.apellido,
    required this.puesto,
    required this.seniority,
    required this.area,
    required this.mail,
  });
}