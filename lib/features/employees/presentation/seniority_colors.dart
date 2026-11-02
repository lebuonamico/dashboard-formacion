import 'package:app_finnegans/core/theme/app_colors.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';

extension SeniorityColors on AppColors {
  ColorPair level(Seniority seniority) => switch (seniority) {
    Seniority.trainee => trainee,
    Seniority.junior1 || Seniority.junior2 || Seniority.junior3 => junior,
    Seniority.semisenior1 ||
    Seniority.semisenior2 ||
    Seniority.semisenior3 => semisenior,
    Seniority.senior1 || Seniority.senior2 || Seniority.senior3 => senior,
    Seniority.manager => manager,
  };
}
