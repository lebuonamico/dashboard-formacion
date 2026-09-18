import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';

class ConfiguracionScreen extends ConsumerStatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  ConsumerState<ConfiguracionScreen> createState() =>
      _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends ConsumerState<ConfiguracionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              children: [
                // TopBar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Configuración del Sistema',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0D53C3),
                        child: const Text(
                          'U',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido de Configuración
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      _buildSeccionImportacion(context),
                      const SizedBox(height: 24),
                      _buildSeccionCursos(context),
                      const SizedBox(height: 24),
                      _buildSeccionCargaDeHoras(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionImportacion(BuildContext context) {
    return _ConfigCard(
      titulo: 'Carga de Nómina de Empleados',
      subtitulo:
          'Importá un archivo Excel o CSV con los datos de los empleados',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.table_chart_outlined,
              color: Color(0xFF1D4ED8),
            ),
          ),
          title: const Text(
            'Importar nómina desde Excel / CSV',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Cargá la nómina de empleados para actualizar el sistema',
          ),
          trailing: OutlinedButton.icon(
            onPressed: _importarArchivo,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Cargar Nómina'),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionCursos(BuildContext context) {
    return _ConfigCard(
      titulo: 'Carga de Cursos',
      subtitulo:
          'Importá el catálogo de cursos desde Moodle u otro archivo Excel / CSV',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.school_outlined, color: Color(0xFF15803D)),
          ),
          title: const Text(
            'Importar cursos desde Excel / CSV',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'El área y el instructor se completan posteriormente desde las cursadas',
          ),
          trailing: OutlinedButton.icon(
            onPressed: _importarCursosArchivo,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Cargar Cursos'),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionCargaDeHoras(BuildContext context) {
    return _ConfigCard(
      titulo: 'Carga de horas CRM',
      subtitulo: 'Importá las horas tomadas y dictadas desde el reporte de CRM',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.schedule, color: Color(0xFFC2410C)),
          ),
          title: const Text(
            'Importar carga de horas desde Excel / CSV',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Solo se consideran registros del proyecto 01 - Capacitación',
          ),
          trailing: OutlinedButton.icon(
            onPressed: _importarCargaDeHoras,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Cargar Horas'),
          ),
        ),
      ],
    );
  }

  Future<void> _importarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    try {
      final extension = result.files.single.extension?.toLowerCase();
      final rowsPorHoja = extension == 'xlsx'
          ? _leerExcel(result.files.single.bytes!)
          : {
              'CSV': const CsvToListConverter(shouldParseNumbers: false)
                  .convert(
                    utf8
                        .decode(result.files.single.bytes!)
                        .replaceFirst('\ufeff', ''),
                  ),
            };
      final empleadosRepository = ref.read(empleadosRepositoryProvider);
      final cursosRepository = ref.read(cursosRepositoryProvider);
      final cargaDeHorasRepository = ref.read(
        cargaDeHorasCRMRepositoryProvider,
      );
      if (empleadosRepository is! LocalEmpleadosRepository ||
          cursosRepository is! LocalCursosRepository ||
          cargaDeHorasRepository is! LocalCargaDeHorasCRMRepository) {
        throw const FormatException('El repositorio local no está disponible.');
      }

      final empleados = await empleadosRepository.getEmpleados();
      final cursos = await cursosRepository.getCursos();
      final cargasDeHoras = await cargaDeHorasRepository.getCargasDeHoras();
      var empleadosImportados = [...empleados];
      var cursosImportados = [...cursos];
      var cargasDeHorasImportadas = [...cargasDeHoras];
      var empleadosReemplazados = false;
      var cursosReemplazados = false;

      var registrosImportados = 0;
      for (final rows in rowsPorHoja.values) {
        if (rows.length < 2) continue;
        final headerIndex = _buscarFilaEncabezados(rows);
        if (headerIndex == -1) continue;
        final headers = rows[headerIndex]
            .map((header) => _normalize(header.toString()))
            .toList();
        final seniorityIndex = _buscarColumnaSeniority(
          headers,
          rows,
          headerIndex,
        );
        final records = rows
            .skip(headerIndex + 1)
            .where(
              (row) => row.any((cell) => cell.toString().trim().isNotEmpty),
            );

        for (final row in records) {
          final normalizedData = <String, String>{};
          for (
            var index = 0;
            index < headers.length && index < row.length;
            index++
          ) {
            normalizedData[headers[index]] = row[index].toString().trim();
          }
          if ((headers.contains('legajo') ||
                  headers.contains('nlegajo') ||
                  headers.contains('idempleado')) &&
              (headers.contains('nombre') ||
                  headers.contains('nombreyapellido'))) {
            if (!empleadosReemplazados) {
              empleadosImportados = [];
              empleadosReemplazados = true;
            }
            final empleadoData = _toCanonicalKeys(normalizedData, {
              'nlegajo': 'legajo',
              'idempleado': 'legajo',
              'nombreyapellido': 'nombre',
              'nivel': 'seniority',
              'nivelseniority': 'seniority',
              'niveldeseniority': 'seniority',
              'senioridad': 'seniority',
              'categoria': 'seniority',
              'niveljerarquico': 'seniority',
              'grado': 'seniority',
              'email': 'mail',
              'correo': 'mail',
              'correoelectronico': 'mail',
              'gerencia': 'area',
              'sector': 'area',
              'departamento': 'area',
              'unidad': 'area',
              'team': 'equipo',
              'equipo': 'equipo',
              'equipogeneral': 'equipo',
              'equipofuncional': 'equipo',
              'equipoprincipal': 'equipo',
              'manager': 'gerente',
              'jefe': 'gerente',
              'supervisor': 'gerente',
              'reportaa': 'gerente',
              for (final header in headers)
                if (_esColumnaSeniority(header)) header: 'seniority',
            });
            if (seniorityIndex != -1 && seniorityIndex < row.length) {
              empleadoData['seniority'] = Seniority.fromString(
                row[seniorityIndex].toString().trim(),
              ).name;
            }
            final empleado = Empleado.fromJson(empleadoData);
            empleadosImportados = _reemplazarPorId(
              empleadosImportados,
              empleado,
              (item) => item.legajo,
            );
          } else if (headers.contains('cursoid') &&
              headers.contains('empleadolegajo')) {
            final cargaData = _toCanonicalKeys(normalizedData, {
              'cursoid': 'cursoId',
              'empleadolegajo': 'empleadoLegajo',
              'horastotales': 'horasTotales',
            });
            final carga = CargaDeHorasCRM.fromJson({
              ...cargaData,
              'tipo': TipoCargaDeHoras.tomada.name,
            });
            if (carga.id.isNotEmpty) {
              cargasDeHorasImportadas = _reemplazarPorId(
                cargasDeHorasImportadas,
                carga,
                (item) => item.id,
              );
            }
          } else if (headers.contains('id') &&
              headers.contains('nombre') &&
              headers.contains('tipo')) {
            if (!cursosReemplazados) {
              cursosImportados = [];
              cursosReemplazados = true;
            }
            final curso = Curso.fromJson(
              _toCanonicalKeys(normalizedData, {
                'areacurso': 'areaCurso',
                'instructorlegajo': 'instructorLegajo',
                'cargahorariahs': 'cargaHorariaHs',
              }),
            );
            cursosImportados = _reemplazarPorId(
              cursosImportados,
              curso,
              (item) => item.id,
            );
          } else {
            throw FormatException(
              'Encabezados no reconocidos en una hoja del archivo.',
            );
          }
          registrosImportados++;
        }
      }
      if (registrosImportados == 0) {
        throw const FormatException('El archivo no tiene registros.');
      }

      await Future.wait([
        empleadosRepository.replaceEmpleados(empleadosImportados),
        cursosRepository.replaceCursos(cursosImportados),
        cargaDeHorasRepository.replaceCargasDeHoras(cargasDeHorasImportadas),
      ]);
      ref.invalidate(empleadosProvider);
      ref.invalidate(cursosProvider);
      ref.invalidate(cargasDeHorasCRMProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se importaron $registrosImportados registros desde ${result.files.single.name}.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo CSV.')),
      );
    }
  }

  Future<void> _importarCursosArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    try {
      final extension = result.files.single.extension?.toLowerCase();
      final rowsPorHoja = extension == 'xlsx'
          ? _leerExcel(result.files.single.bytes!)
          : {
              'CSV': const CsvToListConverter(shouldParseNumbers: false)
                  .convert(
                    utf8
                        .decode(result.files.single.bytes!)
                        .replaceFirst('\ufeff', ''),
                  ),
            };
      final repository = ref.read(cursosRepositoryProvider);
      if (repository is! LocalCursosRepository) {
        throw const FormatException('El repositorio local no está disponible.');
      }

      final cursosImportados = <Curso>[];
      for (final rows in rowsPorHoja.values) {
        if (rows.length < 2) continue;
        final headerIndex = _buscarFilaCursos(rows);
        if (headerIndex == -1) continue;
        final headers = rows[headerIndex]
            .map((header) => _normalize(header.toString()))
            .toList();
        final idIndex = _buscarColumna(headers, const [
          'id',
          'cursoid',
          'courseid',
          'iddelcurso',
          'idcurso',
          'shortname',
          'courseshortname',
          'codigo',
        ]);
        final nombreIndex = _buscarColumna(headers, const [
          'nombre',
          'nombrecurso',
          'course',
          'coursename',
          'fullname',
          'coursefullname',
          'nombrecompleto',
          'titulo',
        ]);
        if (idIndex == -1 || nombreIndex == -1) continue;

        for (final row in rows.skip(headerIndex + 1)) {
          if (idIndex >= row.length || nombreIndex >= row.length) continue;
          final id = row[idIndex].toString().trim();
          final nombre = row[nombreIndex].toString().trim();
          if (id.isEmpty || nombre.isEmpty) continue;
          final tipoIndex = _buscarColumna(headers, const [
            'tipo',
            'tipocurso',
            'category',
            'categoria',
          ]);
          final horasIndex = _buscarColumna(headers, const [
            'cargahorariahs',
            'cargahoraria',
            'horas',
            'hours',
          ]);
          cursosImportados.add(
            Curso(
              id: id,
              nombre: nombre,
              tipo: tipoIndex != -1 && tipoIndex < row.length
                  ? _tipoCursoDesdeTexto(row[tipoIndex].toString())
                  : TipoCurso.libresExploracion,
              areaCurso: '',
              instructorLegajo: '',
              cargaHorariaHs: horasIndex != -1 && horasIndex < row.length
                  ? double.tryParse(
                          row[horasIndex].toString().replaceAll(',', '.'),
                        ) ??
                        0
                  : 0,
            ),
          );
        }
      }

      if (cursosImportados.isEmpty) {
        throw const FormatException(
          'No se encontraron cursos. Verificá las columnas de ID y nombre.',
        );
      }
      await repository.replaceCursos(cursosImportados);
      ref.invalidate(cursosProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se cargaron ${cursosImportados.length} cursos desde ${result.files.single.name}.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo de cursos.')),
      );
    }
  }

  Future<void> _importarCargaDeHoras() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    try {
      final extension = result.files.single.extension?.toLowerCase();
      final rowsPorHoja = extension == 'xlsx'
          ? _leerExcel(result.files.single.bytes!)
          : {
              'CSV': const CsvToListConverter(shouldParseNumbers: false)
                  .convert(
                    utf8
                        .decode(result.files.single.bytes!)
                        .replaceFirst('\ufeff', ''),
                  ),
            };
      final repository = ref.read(cargaDeHorasCRMRepositoryProvider);
      if (repository is! LocalCargaDeHorasCRMRepository) {
        throw const FormatException('El repositorio local no está disponible.');
      }

      final cargasImportadas = <CargaDeHorasCRM>[];
      for (final rows in rowsPorHoja.values) {
        if (rows.length < 2) continue;
        final headerIndex = _buscarFilaCargaDeHoras(rows);
        if (headerIndex == -1) continue;
        final headers = rows[headerIndex]
            .map((header) => _normalize(header.toString()))
            .toList();
        final idIndex = _buscarColumnaCRM(headers, 'id');
        final legajoIndex = _buscarColumnaCRM(headers, 'legajo');
        final fechaIndex = _buscarColumnaCRM(headers, 'fecha');
        final descripcionIndex = _buscarColumnaCRM(headers, 'caso');
        final proyectoIndex = _buscarColumnaProyectoItem(headers);
        final horasIndex = _buscarColumnaCRM(headers, 'horas');
        if ([
          idIndex,
          legajoIndex,
          fechaIndex,
          descripcionIndex,
          proyectoIndex,
          horasIndex,
        ].any((index) => index == -1)) {
          continue;
        }

        for (final row in rows.skip(headerIndex + 1)) {
          if ([
            idIndex,
            legajoIndex,
            fechaIndex,
            descripcionIndex,
            proyectoIndex,
            horasIndex,
          ].any((index) => index >= row.length)) {
            continue;
          }
          final proyecto = _normalize(row[proyectoIndex].toString());
          if (proyecto != '01capacitacion') {
            continue;
          }

          final descripcion = row[descripcionIndex].toString().trim();
          final tipo = _tipoCargaDesdeDescripcion(descripcion);
          final cursoId = _cursoIdDesdeDescripcion(descripcion);
          if (tipo == null || cursoId.isEmpty) continue;

          final horas =
              double.tryParse(
                row[horasIndex].toString().replaceAll(',', '.'),
              ) ??
              0;
          if (horas <= 0) continue;
          final id = row[idIndex].toString().trim();
          final legajo = row[legajoIndex].toString().trim();
          if (id.isEmpty || legajo.isEmpty) continue;

          cargasImportadas.add(
            CargaDeHorasCRM(
              id: id,
              cursoId: cursoId,
              empleadoLegajo: legajo,
              fecha: _fechaDesdeCelda(row[fechaIndex].toString()),
              horasTotales: horas,
              tipo: tipo,
            ),
          );
        }
      }

      if (cargasImportadas.isEmpty) {
        throw const FormatException(
          'No se encontraron cargas válidas del proyecto 01 - Capacitación.',
        );
      }
      await repository.replaceCargasDeHoras(cargasImportadas);
      ref.invalidate(cargasDeHorasCRMProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se cargaron ${cargasImportadas.length} registros desde ${result.files.single.name}.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo de horas.')),
      );
    }
  }

  Map<String, List<List<dynamic>>> _leerExcel(List<int> bytes) {
    final workbook = excel.Excel.decodeBytes(bytes);
    return {
      for (final entry in workbook.tables.entries)
        entry.key: entry.value.rows
            .map((row) => row.map((cell) => _valorCelda(cell?.value)).toList())
            .toList(),
    };
  }

  String _valorCelda(excel.CellValue? value) {
    if (value == null) return '';
    if (value is excel.TextCellValue) return _textoSpan(value.value);
    if (value is excel.IntCellValue) return value.value.toString();
    if (value is excel.DoubleCellValue) return value.value.toString();
    if (value is excel.BoolCellValue) return value.value.toString();
    return value.toString();
  }

  String _textoSpan(excel.TextSpan span) {
    return (span.text ?? '') +
        (span.children ?? const <excel.TextSpan>[]).map(_textoSpan).join();
  }

  List<T> _reemplazarPorId<T>(
    List<T> actuales,
    T nuevo,
    String Function(T) id,
  ) {
    final index = actuales.indexWhere((item) => id(item) == id(nuevo));
    if (index == -1) return [...actuales, nuevo];
    final resultado = [...actuales]..[index] = nuevo;
    return resultado;
  }

  int _buscarFilaEncabezados(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => _normalize(cell.toString()))
          .toSet();
      if ((headers.contains('legajo') ||
              headers.contains('nlegajo') ||
              headers.contains('idempleado')) &&
          (headers.contains('nombre') || headers.contains('nombreyapellido'))) {
        return index;
      }
    }
    return -1;
  }

  int _buscarFilaCursos(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => _normalize(cell.toString()))
          .toSet();
      final tieneId = headers.any(
        const {
          'id',
          'cursoid',
          'courseid',
          'iddelcurso',
          'idcurso',
          'shortname',
          'courseshortname',
          'codigo',
        }.contains,
      );
      final tieneNombre = headers.any(
        const {
          'nombre',
          'nombrecurso',
          'course',
          'coursename',
          'fullname',
          'coursefullname',
          'nombrecompleto',
          'titulo',
        }.contains,
      );
      if (tieneId && tieneNombre) return index;
    }
    return -1;
  }

  int _buscarFilaCargaDeHoras(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => _normalize(cell.toString()))
          .toSet();
      if (_buscarColumnaCRM(headers.toList(), 'id') != -1 &&
          _buscarColumnaCRM(headers.toList(), 'legajo') != -1 &&
          _buscarColumnaCRM(headers.toList(), 'proyecto') != -1 &&
          _buscarColumnaCRM(headers.toList(), 'horas') != -1) {
        return index;
      }
    }
    return -1;
  }

  int _buscarColumnaCRM(List<String> headers, String campo) {
    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      final coincide = switch (campo) {
        'id' => header.contains('transaccion') && header.contains('id'),
        'legajo' => header.contains('legajo'),
        'fecha' => header == 'fecha' || header.contains('fecha'),
        'caso' =>
          header == 'caso' ||
              header.contains('descripcion') ||
              header.contains('detalle') ||
              header.contains('concepto'),
        'proyecto' =>
          header.contains('proyecto') &&
              (header.contains('item') || header == 'proyecto'),
        'horas' => header.contains('hora') && header.contains('total'),
        _ => false,
      };
      if (coincide) return index;
    }
    return -1;
  }

  int _buscarColumnaProyectoItem(List<String> headers) {
    final exactIndex = headers.indexOf('proyectoitem');
    if (exactIndex != -1) return exactIndex;
    return _buscarColumnaCRM(headers, 'proyecto');
  }

  TipoCargaDeHoras? _tipoCargaDesdeDescripcion(String value) {
    final normalized = _normalize(value);
    if (normalized.startsWith('choras')) return TipoCargaDeHoras.tomada;
    if (normalized.startsWith('casosdeconsultoria')) {
      return TipoCargaDeHoras.dictada;
    }
    return null;
  }

  String _cursoIdDesdeDescripcion(String value) {
    final match = RegExp(
      r'-\s*([a-z0-9][a-z0-9_-]*)\s*$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    return match?.group(1) ?? '';
  }

  DateTime _fechaDesdeCelda(String value) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }

  int _buscarColumna(List<String> headers, List<String> posibles) {
    for (final posible in posibles) {
      final index = headers.indexOf(posible);
      if (index != -1) return index;
    }
    return -1;
  }

  TipoCurso _tipoCursoDesdeTexto(String value) {
    final normalized = _normalize(value);
    for (final tipo in TipoCurso.values) {
      if (_normalize(tipo.name) == normalized ||
          _normalize(tipo.label) == normalized) {
        return tipo;
      }
    }
    if (normalized.contains('negocio') || normalized.contains('business')) {
      return TipoCurso.habilidadesDeNegocio;
    }
    if (normalized.contains('blanda') || normalized.contains('soft')) {
      return TipoCurso.habilidadesBlandas;
    }
    if (normalized.contains('dictad') || normalized.contains('impart')) {
      return TipoCurso.dictadoCapacitaciones;
    }
    return TipoCurso.libresExploracion;
  }

  bool _esColumnaSeniority(String header) {
    return header == 'seniority' ||
        header.contains('seniority') ||
        header == 'senioridad' ||
        header == 'nivel' ||
        header == 'nivelseniority' ||
        header == 'niveldeseniority' ||
        header == 'niveljerarquico' ||
        header == 'categoria' ||
        header == 'grado';
  }

  int _buscarColumnaSeniority(
    List<String> headers,
    List<List<dynamic>> rows,
    int headerIndex,
  ) {
    const encabezadosEspecificos = {
      'seniority',
      'nivelseniority',
      'niveldeseniority',
      'senioridad',
      'niveljerarquico',
    };
    final indiceEspecifico = headers.indexWhere(
      encabezadosEspecificos.contains,
    );
    if (indiceEspecifico != -1) return indiceEspecifico;

    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      if (_esColumnaSeniority(header)) {
        return index;
      }
    }

    var mejorIndice = -1;
    var mayorCantidadCoincidencias = 0;
    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      final cantidadCoincidencias = rows
          .skip(headerIndex + 1)
          .take(50)
          .where((row) => columnIndex < row.length)
          .map((row) => row[columnIndex].toString())
          .where(_pareceValorSeniority)
          .length;
      if (cantidadCoincidencias > mayorCantidadCoincidencias) {
        mayorCantidadCoincidencias = cantidadCoincidencias;
        mejorIndice = columnIndex;
      }
    }
    if (mayorCantidadCoincidencias > 0) return mejorIndice;

    return -1;
  }

  bool _pareceValorSeniority(String value) {
    final normalized = _normalize(value);
    return RegExp(
      r'^(?:senior|senor|sr|ssr|ss|junior|jr|j[123]|trainee|manager|gerente)',
    ).hasMatch(normalized);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  Map<String, dynamic> _toCanonicalKeys(
    Map<String, String> data,
    Map<String, String> aliases,
  ) {
    return {
      for (final entry in data.entries)
        aliases[entry.key] ?? entry.key: entry.value,
    };
  }
}

class _ConfigCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final List<Widget> children;

  const _ConfigCard({
    required this.titulo,
    required this.subtitulo,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
