import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';

// The texts of the message sent to the asistente-ia Edge Function belong to
// its contract: they do not follow the UI labels.

extension AssistantModulePayload on AssistantModule {
  String get payloadValue => switch (this) {
    AssistantModule.dashboard => 'Dashboard',
    AssistantModule.areas => 'Áreas',
    AssistantModule.teams => 'Equipos',
    AssistantModule.teamDetail => 'Detalle de equipo',
    AssistantModule.people => 'Personas',
    AssistantModule.courses => 'Cursos',
    AssistantModule.settings => 'Configuración',
    AssistantModule.others => 'Ayuda general',
  };
}

extension AssistantTopicPayload on AssistantTopic {
  String get payloadValue => switch (this) {
    AssistantTopic.general => 'general',
    AssistantTopic.areas => 'areas',
    AssistantTopic.teams => 'equipos',
    AssistantTopic.person => 'persona',
    AssistantTopic.courses => 'cursos',
    AssistantTopic.import => 'importacion',
    AssistantTopic.conceptual => 'conceptual',
  };
}

extension SeniorityPayload on Seniority {
  String get payloadValue => switch (this) {
    Seniority.trainee => 'Trainee',
    Seniority.junior1 => 'Junior 1',
    Seniority.junior2 => 'Junior 2',
    Seniority.junior3 => 'Junior 3',
    Seniority.semisenior1 => 'Semisenior 1',
    Seniority.semisenior2 => 'Semisenior 2',
    Seniority.semisenior3 => 'Semisenior 3',
    Seniority.senior1 => 'Senior 1',
    Seniority.senior2 => 'Senior 2',
    Seniority.senior3 => 'Senior 3',
    Seniority.manager => 'Manager',
  };
}

extension CourseCategoryPayload on CourseCategory {
  String get payloadValue => switch (this) {
    CourseCategory.businessSkills => 'Habilidades de negocio',
    CourseCategory.softSkills => 'Habilidades blandas',
    CourseCategory.exploration => 'Libres / exploración',
    CourseCategory.teaching => 'Dictado de capacitaciones',
  };
}

extension TeamStatusPayload on TeamStatus {
  String get payloadValue => switch (this) {
    TeamStatus.onTarget => 'En objetivo',
    TeamStatus.atRisk => 'En riesgo',
    TeamStatus.critical => 'Crítico',
  };
}

extension ComplianceLevelPayload on ComplianceLevel {
  String get payloadValue => switch (this) {
    ComplianceLevel.onTarget => 'En objetivo',
    ComplianceLevel.atRisk => 'En riesgo',
    ComplianceLevel.critical => 'Crítico',
  };
}
