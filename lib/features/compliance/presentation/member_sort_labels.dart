import 'package:app_finnegans/features/compliance/domain/member_order.dart';

extension MemberSortLabel on MemberSort {
  String get label => switch (this) {
    MemberSort.employeeId => 'Legajo',
    MemberSort.employee => 'Colaborador',
    MemberSort.team => 'Equipo',
    MemberSort.seniority => 'Seniority',
    MemberSort.hours => 'Horas válidas',
    MemberSort.compliance => 'Cumplimiento',
  };
}
