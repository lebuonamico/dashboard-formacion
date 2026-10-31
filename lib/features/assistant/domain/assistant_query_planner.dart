import 'dart:math' as math;

import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_exception.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/sensitive_text.dart';

enum QuestionIssue { empty, tooLong, sensitive }

/// Reads the intent and the periods of a question. Calculates no KPI.
class AssistantQueryPlanner {
  static const maxQuestion = 1200;
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  final SensitiveTextDetector sensitive;

  const AssistantQueryPlanner({this.sensitive = const SensitiveTextDetector()});

  String normalize(String text) => normalizeKey(text, separator: ' ');

  QuestionIssue? validate(String question) {
    if (question.trim().isEmpty) return QuestionIssue.empty;
    if (question.length > maxQuestion) return QuestionIssue.tooLong;
    if (sensitive.isSensitive(question)) return QuestionIssue.sensitive;
    return null;
  }

  bool totalsOnly(String question) =>
      RegExp(
        r'\b(?:cuant[oa]s|cantidad de|total de)\s+(?:equipos|areas|cursos)\b',
      ).hasMatch(normalize(question)) &&
      !RegExp(
        r'cuales|compar|recom|lista|menor|mayor',
      ).hasMatch(normalize(question));

  AssistantQuery plan(
    String question,
    AssistantDestination destination,
    PeriodFilter visibleFilter,
  ) {
    final visible = AssistantPeriod(
      year: visibleFilter.year,
      month: visibleFilter.month,
      annual: visibleFilter.scope == PeriodScope.annual,
    );
    final q = normalize(question);
    bool has(String pattern) => RegExp(pattern).hasMatch(q);
    final evolution = has(r'evoluci|tendencia|mes a mes|historico');
    final notes = <String>[];
    final periods = <AssistantPeriod>[];
    final mentions = <({int start, int end, int month, int? year})>[];
    final temporaryText = question.toLowerCase();
    final years = RegExp(
      r'(?<!\d)((?:19|20|21)\d{2})(?!\d)',
    ).allMatches(q).map((m) => int.parse(m[1]!)).toSet();
    final commonYear = years.length == 1 ? years.single : visible.year;
    final months = RegExp(
      r'\b(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre|ene|feb|mar|abr|may|jun|jul|ago|sept|sep|oct|nov|dic)(?:\s*(?:de\s+|del\s+)?((?:19|20|21)\d{2}))?\b',
    );
    mentions.addAll(
      months
          .allMatches(temporaryText)
          .map(
            (m) => (
              start: m.start,
              end: m.end,
              month: m[1] == 'setiembre'
                  ? 9
                  : _months.indexWhere((name) => name.startsWith(m[1]!)) + 1,
              year: int.tryParse(m[2] ?? ''),
            ),
          ),
    );
    final numericMentions =
        RegExp(
              r'\b((?:19|20|21)\d{2})[-/](\d{1,2})(?![-/\d])|\b(\d{1,2})[-/]((?:19|20|21)\d{2})\b',
            )
            .allMatches(temporaryText)
            .where(
              (m) => !mentions.any((p) => p.start < m.end && p.end > m.start),
            )
            .map((m) {
              final month = int.parse((m[2] ?? m[3])!);
              if (month < 1 || month > 12) {
                throw const AssistantQueryException(
                  AssistantQueryIssue.invalidMonth,
                );
              }
              return (
                start: m.start,
                end: m.end,
                month: month,
                year: int.parse((m[1] ?? m[4])!),
              );
            })
            .toList();
    mentions
      ..addAll(numericMentions)
      ..sort((a, b) => a.start.compareTo(b.start));
    periods.addAll(
      mentions.map(
        (mention) => AssistantPeriod(
          year: mention.year ?? commonYear,
          month: mention.month,
        ),
      ),
    );
    if (periods.isEmpty) {
      final numericMonth = RegExp(r'\bmes\s+(\d{1,2})\b').firstMatch(q);
      if (numericMonth != null) {
        final month = int.parse(numericMonth[1]!);
        if (month < 1 || month > 12) {
          throw const AssistantQueryException(AssistantQueryIssue.invalidMonth);
        }
        periods.add(AssistantPeriod(year: commonYear, month: month));
      }
    }
    // Only the ends joined by a connector make a range, not every month in
    // the question: an explanation may mention any of them again.
    final ranges =
        List.generate(
              math.max(0, mentions.length - 1),
              (i) => (from: mentions[i], until: mentions[i + 1]),
            )
            .where(
              (pair) => _isRangeConnector(
                temporaryText.substring(pair.from.end, pair.until.start),
                temporaryText.substring(0, pair.from.start),
              ),
            )
            .map((pair) {
              final (:from, :until) = pair;
              var yearFrom = from.year ?? until.year ?? commonYear;
              var yearUntil = until.year ?? from.year ?? commonYear;
              if (until.month < from.month) {
                if (from.year == null && until.year != null) {
                  yearFrom--;
                } else if (until.year == null) {
                  yearUntil++;
                }
              }
              return (
                start: DateTime(yearFrom, from.month),
                end: DateTime(yearUntil, until.month),
              );
            })
            .toSet()
            .toList();
    final explicitRange = ranges.length == 1;
    if (explicitRange) {
      final range = ranges.single;
      periods
        ..clear()
        ..addAll([
          AssistantPeriod(year: range.start.year, month: range.start.month),
          AssistantPeriod(year: range.end.year, month: range.end.month),
        ]);
    }
    final accumulated = explicitRange && !evolution;
    if (ranges.length > 1) {
      periods.clear();
      notes.add(
        'Se identificaron varios rangos diferentes. Indicá un solo rango de inicio a fin; no se mezclaron sus períodos ni se usó el visible.',
      );
    } else if ((has(r'trimestre|semestre') && !explicitRange) ||
        has(r'\bsemana|\bdia\b|\bdiario') ||
        RegExp(
          r'\b\d{1,2}/\d{1,2}/(?:19|20|21)\d{2}\b|\b(?:19|20|21)\d{2}-\d{1,2}-\d{1,2}\b',
        ).hasMatch(question)) {
      notes.add(
        'Esta consulta temporal necesita precisarse como mes/año o año completo. No se enviaron indicadores de un período diferente.',
      );
      periods.clear();
    } else if (periods.isEmpty) {
      if (has(r'mes (pasado|anterior)')) {
        final date = DateTime(visible.year, visible.month - 1);
        periods.add(AssistantPeriod(year: date.year, month: date.month));
        notes.add(
          'Mes anterior relativo al período visible, no a la fecha del sistema.',
        );
      } else if (has(r'ano (pasado|anterior)')) {
        periods.add(
          AssistantPeriod(
            year: visible.year - 1,
            month: visible.month,
            annual: true,
          ),
        );
        notes.add(
          'Año anterior relativo al año seleccionado en la aplicación.',
        );
      } else if (has(r'anual|\bano\b|\banos\b') || years.isNotEmpty) {
        periods.addAll(
          (years.isEmpty ? {visible.year} : years).map(
            (year) =>
                AssistantPeriod(year: year, month: visible.month, annual: true),
          ),
        );
      } else {
        periods.add(visible);
      }
    } else if (years.isEmpty) {
      notes.add(
        explicitRange
            ? 'El año no se indicó: el rango comienza en ${visible.year}, seleccionado en la aplicación; si cruza diciembre continúa en el año siguiente.'
            : 'El año no se indicó: se usa ${visible.year}, seleccionado en la aplicación.',
      );
    }
    if (explicitRange && has(r'\banual\b|ano completo|acumulado del ano')) {
      periods.clear();
      notes.add(
        'La consulta mezcla un rango de meses y un acumulado anual. Precisá cuál necesitás; no se sustituyó el rango por el año completo.',
      );
    } else if (!evolution &&
        has(r'\banual\b|ano completo|acumulado del ano') &&
        periods.any((p) => !p.annual)) {
      if (has(r'acumulado anual|total anual|ano completo|acumulado del ano')) {
        final annualYears = RegExp(
          r'\b(?:acumulado anual|total anual|ano completo|acumulado del ano)(?:\s+(?:de|del))?\s+((?:19|20|21)\d{2})\b',
        ).allMatches(q).map((m) => int.parse(m[1]!)).toSet();
        if (annualYears.isEmpty && years.length <= 1) {
          annualYears.addAll(periods.map((p) => p.year));
        }
        if (annualYears.isEmpty) {
          periods.clear();
          notes.add(
            'Hay varios años en la consulta. Indicá el año del acumulado anual; no se eligió uno por suposición.',
          );
        } else {
          periods.addAll(
            annualYears.map(
              (year) => AssistantPeriod(
                year: year,
                month: visible.month,
                annual: true,
              ),
            ),
          );
        }
      } else {
        periods.clear();
        notes.add(
          'Se pidió simultáneamente un análisis anual y mensual. Precisá el alcance; no se enviaron indicadores de otro período.',
        );
      }
    }
    if ((evolution || explicitRange) && periods.isNotEmpty) {
      final first = periods.first;
      final last = periods.last;
      final start = periods.length > 1
          ? DateTime(first.year, first.month)
          : DateTime(first.year);
      final end = DateTime(last.year, last.annual ? 12 : last.month);
      final count = (end.year - start.year) * 12 + end.month - start.month + 1;
      if (count < 1 || count > 12) {
        periods.clear();
        notes.add(
          'Los rangos y la evolución admiten hasta doce meses consecutivos en orden cronológico. Precisá los meses y años de inicio y fin.',
        );
      } else {
        periods.clear();
        periods.addAll(
          List.generate(count, (i) {
            final date = DateTime(start.year, start.month + i);
            return AssistantPeriod(year: date.year, month: date.month);
          }),
        );
      }
    } else if (periods.length > 3) {
      periods.clear();
      notes.add(
        'Las comparaciones detalladas admiten hasta tres períodos por consulta. No se sustituyeron por el período visible.',
      );
    }
    if (!evolution && !accumulated && periods.length > 1) {
      notes.add(
        'Cada bloque corresponde a su período. No fusionar meses ni deducir un acumulado del rango. La aplicación dispone de acumulados anuales; usar solo los incluidos en esta consulta.',
      );
    }
    final asksForAccumulated = accumulated && has(r'\bacumulad');
    final AssistantTopic theme;
    if (has(r'importa|archivo|csv|xlsx|configuracion')) {
      theme = AssistantTopic.import;
    } else if (!asksForAccumulated &&
        has(
          r'que significa|como se calcula|como funciona|por que.*sin datos',
        )) {
      theme = AssistantTopic.conceptual;
    } else if (has(r'recom|catalogo|\bcursos?\b')) {
      theme = AssistantTopic.courses;
    } else if (has(r'\barea\b|\bareas\b|departamento')) {
      theme = AssistantTopic.areas;
    } else if (has(r'\bequipo\b|\bequipos\b')) {
      theme = AssistantTopic.teams;
    } else if (destination.employeeId != null ||
        has(r'colaborador seleccionado|persona seleccionada')) {
      theme = AssistantTopic.person;
    } else if (destination.area == null &&
        destination.team == null &&
        has(r'acumulad') &&
        has(r'cumplimiento|horas|objetivo')) {
      theme = AssistantTopic.general;
    } else {
      theme = switch (destination.module) {
        AssistantModule.areas => AssistantTopic.areas,
        AssistantModule.teams ||
        AssistantModule.teamDetail => AssistantTopic.teams,
        AssistantModule.people => AssistantTopic.person,
        AssistantModule.courses => AssistantTopic.courses,
        AssistantModule.settings => AssistantTopic.import,
        _ => AssistantTopic.general,
      };
    }
    return AssistantQuery(
      destination: destination,
      theme: theme,
      question: question,
      periods: periods,
      notes: notes,
      evolution: evolution,
      accumulated: accumulated && periods.isNotEmpty,
    );
  }

  bool _isRangeConnector(String link, String previous) {
    final connector = normalize(link);
    return RegExp(
          r'^(?:y )?(?:a|al|hasta)(?: el)?(?: mes(?: de)?)?$',
        ).hasMatch(connector) ||
        (connector == 'y' &&
            RegExp(
              r'\bentre(?: (?:el mes|los meses)(?: de)?)?$',
            ).hasMatch(normalize(previous))) ||
        RegExp(r'^\s*[-–—]\s*$').hasMatch(link);
  }
}
