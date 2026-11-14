import 'package:app_finnegans/core/formatting/hours_formatter.dart';
import 'package:app_finnegans/core/formatting/text_formatter.dart';
import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/record_card.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:flutter/material.dart';

/// The courses the employee taught: a table on desktop, a list of cards below
/// 840 px.
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

    if (context.windowSize != WindowSize.expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: taught.map(_TaughtCourseCard.new).toList(),
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

class _TaughtCourseCard extends StatelessWidget {
  final TaughtCourse course;

  const _TaughtCourseCard(this.course);

  @override
  Widget build(BuildContext context) => RecordCard(
    key: ValueKey('dictado_${course.code}'),
    leading: Icon(
      Icons.co_present_outlined,
      color: context.colors.teaching.text,
      size: 20,
    ),
    title: course.name,
    subtitle: 'ID ${course.code}',
    metrics: [
      RecordMetric('Área temática', orDash(course.area)),
      RecordMetric('Horas sumadas al plan', '${formatHours(course.hours)} hs'),
    ],
  );
}
