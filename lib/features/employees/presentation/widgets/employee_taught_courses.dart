import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:flutter/material.dart';

class EmployeeTaughtCourses extends StatelessWidget {
  final List<TaughtCourse> taught;

  const EmployeeTaughtCourses(this.taught, {super.key});

  @override
  Widget build(BuildContext context) {
    if (taught.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: context.panel(),
        child: const Center(
          child: Text('No registra cursos dictados como instructor.'),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: context.panel(),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                context.colorScheme.surfaceContainerLow,
              ),
              columns: const [
                DataColumn(
                  label: Text(
                    'ID',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Curso dictado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Área temática',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Horas sumadas al plan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: taught
                  .map(
                    (course) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            course.code,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Text(
                            course.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(Text(course.area)),
                        DataCell(
                          Text(
                            '${formatHours(course.hours)} hs',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: context.colors.teaching.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
