import 'package:flutter/widgets.dart';

/// Franja libre al pie de todas las pantallas: ahí flotan el botón del
/// asistente IA y, en el deploy, el badge de Netlify, sin tapar contenido.
/// Las pantallas con tablas paginadas calculan las filas con el alto restante.
const double reservaInferiorFlotantes = 48;

/// Margen del contenido de cada pantalla, debajo del top bar.
const EdgeInsets paddingPantalla = EdgeInsets.fromLTRB(
  24,
  24,
  24,
  24 + reservaInferiorFlotantes,
);
