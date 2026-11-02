import 'package:app_finnegans/features/assistant/domain/assistant_payload_values.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:flutter_test/flutter_test.dart';

Map<T, String> _values<T extends Enum>(
  List<T> values,
  String Function(T value) payload,
) => {for (final value in values) value: payload(value)};

void main() {
  group('Textos del payload del asistente', () {
    test('pantalla', () {
      expect(_values(AssistantModule.values, (m) => m.payloadValue), {
        AssistantModule.dashboard: 'Dashboard',
        AssistantModule.areas: 'Áreas',
        AssistantModule.teams: 'Equipos',
        AssistantModule.teamDetail: 'Detalle de equipo',
        AssistantModule.people: 'Personas',
        AssistantModule.courses: 'Cursos',
        AssistantModule.settings: 'Configuración',
        AssistantModule.others: 'Ayuda general',
      });
    });

    test('tema, con los códigos en español', () {
      expect(_values(AssistantTopic.values, (t) => t.payloadValue), {
        AssistantTopic.general: 'general',
        AssistantTopic.areas: 'areas',
        AssistantTopic.teams: 'equipos',
        AssistantTopic.person: 'persona',
        AssistantTopic.courses: 'cursos',
        AssistantTopic.import: 'importacion',
        AssistantTopic.conceptual: 'conceptual',
      });
    });

    test('seniority', () {
      expect(_values(Seniority.values, (s) => s.payloadValue), {
        Seniority.trainee: 'Trainee',
        Seniority.junior1: 'Junior 1',
        Seniority.junior2: 'Junior 2',
        Seniority.junior3: 'Junior 3',
        Seniority.semisenior1: 'Semisenior 1',
        Seniority.semisenior2: 'Semisenior 2',
        Seniority.semisenior3: 'Semisenior 3',
        Seniority.senior1: 'Senior 1',
        Seniority.senior2: 'Senior 2',
        Seniority.senior3: 'Senior 3',
        Seniority.manager: 'Manager',
      });
    });

    test('categoría', () {
      expect(_values(CourseCategory.values, (c) => c.payloadValue), {
        CourseCategory.businessSkills: 'Habilidades de negocio',
        CourseCategory.softSkills: 'Habilidades blandas',
        CourseCategory.exploration: 'Libres / exploración',
        CourseCategory.teaching: 'Dictado de capacitaciones',
      });
    });

    test('estado de equipo y nivel de área', () {
      expect(_values(TeamStatus.values, (s) => s.payloadValue), {
        TeamStatus.onTarget: 'En objetivo',
        TeamStatus.atRisk: 'En riesgo',
        TeamStatus.critical: 'Crítico',
      });
      expect(_values(ComplianceLevel.values, (l) => l.payloadValue), {
        ComplianceLevel.onTarget: 'En objetivo',
        ComplianceLevel.atRisk: 'En riesgo',
        ComplianceLevel.critical: 'Crítico',
      });
    });
  });
}
