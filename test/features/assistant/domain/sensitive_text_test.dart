import 'package:app_finnegans/features/assistant/domain/sensitive_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const detector = SensitiveTextDetector();

  group('Detecta', () {
    for (final (description, text) in [
      ('un email', '¿Cuántas horas tiene ana.perez@finnegans.com?'),
      ('una arroba suelta', 'el equipo @soporte'),
      ('un link', 'mirá https://academia.finneg.com/curso'),
      ('un link sin https', 'http://localhost:3000'),
      ('un JWT', 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.firma'),
      ('una clave de Google', 'AIzaSyD-ejemplo_123'),
      ('una clave sk-', 'usá sk-proj-abc123'),
      ('un secreto de Supabase', 'sb_secret_abc123'),
      ('una clave publicable de Supabase', 'sb_publishable_abc123'),
      ('un Bearer', 'Authorization: Bearer abc.def'),
      ('una api key con dos puntos', 'api key: 1234'),
      ('una api_key con igual', 'API_KEY=1234'),
      ('una contraseña', 'mi contraseña: hunter2'),
      ('una contrasena sin eñe', 'contrasena=hunter2'),
      ('un password', 'Password = hunter2'),
      ('una clave', 'la clave: 1234'),
      ('un token', 'token:abc'),
      ('un secret', 'secret = xyz'),
      ('un UUID', 'el id 123e4567-e89b-12d3-a456-426614174000'),
      ('una cadena larga', 'a' * 36),
    ]) {
      test(description, () => expect(detector.isSensitive(text), isTrue));
    }
  });

  group('No detecta', () {
    for (final (description, text) in [
      ('una pregunta común', '¿Qué equipos están en riesgo en julio de 2026?'),
      ('la palabra clave sin valor', 'la clave del éxito es la constancia'),
      ('la palabra token sin valor', '¿qué es un token?'),
      ('un legajo', 'el legajo 1234 hizo 8 h'),
      ('un dominio sin protocolo', 'el curso está en academia.finneg.com'),
      ('una cadena de 35 caracteres', 'a' * 35),
      ('un texto vacío', ''),
    ]) {
      test(description, () => expect(detector.isSensitive(text), isFalse));
    }
  });
}
