import 'package:app_finnegans/domain/modelos/resultado_upsert.dart';
import 'package:app_finnegans/presentation/providers/dashboard_providers.dart';
import 'dart:async';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/data/moodle_cursos_api.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/certificaciones_moodle_provider.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracionScreen extends ConsumerStatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  ConsumerState<ConfiguracionScreen> createState() =>
      _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends ConsumerState<ConfiguracionScreen> {
  static const _modoMoodleKey = 'configuracion_cursos_moodle';

  bool _usaMoodle = false;
  bool _modoCargado = false;
  bool _sincronizandoCursos = false;
  final _importacionesEnCurso = <String>{};

  bool get _cursosOcupados =>
      _sincronizandoCursos || _importacionesEnCurso.contains('cursos');

  bool _iniciarImportacion(String tipo) {
    if (_importacionesEnCurso.contains(tipo)) return false;
    setState(() => _importacionesEnCurso.add(tipo));
    return true;
  }

  void _terminarImportacion(String tipo) {
    if (mounted) setState(() => _importacionesEnCurso.remove(tipo));
  }

  Widget _iconoImportacion(String tipo) => _importacionesEnCurso.contains(tipo)
      ? SizedBox.square(
          key: Key('loading_$tipo'),
          dimension: 18,
          child: const CircularProgressIndicator(strokeWidth: 2),
        )
      : const Icon(Icons.upload_file, size: 18);
  List<Curso> _cursosMoodle = [];
  String? _errorCursosMoodle;

  @override
  void initState() {
    super.initState();
    _cargarModoCursos();
  }

  Future<void> _cargarModoCursos() async {
    final preferences = await SharedPreferences.getInstance();
    // La sincronización directa está deshabilitada, incluso si estaba guardada.
    await preferences.setBool(_modoMoodleKey, false);
    if (!mounted) return;
    setState(() {
      _usaMoodle = false;
      _modoCargado = true;
    });
  }

  Future<void> _cambiarModoCursos(bool usaMoodle) async {
    setState(() => _usaMoodle = usaMoodle);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_modoMoodleKey, usaMoodle);
    if (usaMoodle) await _sincronizarCursosMoodle();
  }

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
                        'Configuración del sistema',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const UserAvatar(),
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
                      const SizedBox(height: 24),
                      _buildSeccionCargaLms(context),
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
      titulo: 'Carga de nómina de empleados',
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
            key: const Key('importar_nomina'),
            onPressed: _importacionesEnCurso.contains('nomina')
                ? null
                : _importarArchivo,
            icon: _iconoImportacion('nomina'),
            label: const Text('Cargar nómina'),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionCursos(BuildContext context) {
    return _ConfigCard(
      titulo: 'Carga de cursos',
      subtitulo: 'Elegí cómo actualizar el catálogo de cursos',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Usar API de Moodle',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Sincronización directa no disponible. Usá archivo Excel / CSV.',
          ),
          value: _usaMoodle,
          onChanged: null,
        ),
        if (_usaMoodle) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _sincronizandoCursos
                      ? 'Consultando Moodle...'
                      : '${_cursosMoodle.length} cursos disponibles',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar cursos',
                onPressed: _cursosOcupados ? null : _sincronizarCursosMoodle,
                icon: _sincronizandoCursos
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ],
          ),
          if (_errorCursosMoodle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _errorCursosMoodle!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          if (_cursosMoodle.isNotEmpty)
            SizedBox(
              height: 320,
              child: ListView.separated(
                itemCount: _cursosMoodle.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final curso = _cursosMoodle[index];
                  return ListTile(
                    dense: true,
                    title: Text(curso.nombre),
                    subtitle: Text('ID ${curso.id}'),
                  );
                },
              ),
            )
          else if (!_sincronizandoCursos && _errorCursosMoodle == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No hay cursos cargados.'),
            ),
        ] else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.school_outlined,
                color: Color(0xFF15803D),
              ),
            ),
            title: const Text(
              'Importar cursos desde Excel / CSV',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'El área y el instructor se completan posteriormente desde las cursadas',
            ),
            trailing: OutlinedButton.icon(
              key: const Key('importar_cursos'),
              onPressed: _cursosOcupados ? null : _importarCursosArchivo,
              icon: _iconoImportacion('cursos'),
              label: const Text('Cargar cursos'),
            ),
          ),
      ],
    );
  }

  Future<void> _sincronizarCursosMoodle() async {
    if (!_usaMoodle || _cursosOcupados) return;
    setState(() {
      _sincronizandoCursos = true;
      _errorCursosMoodle = null;
    });
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      var cursos = <Curso>[];
      await container
          .read(importacionServiceProvider)
          .ejecutar(
            tipoArchivo: 'cursos_lms',
            nombreArchivo: 'Sincronización Moodle',
            procesar: () async {
              final repository = container.read(cursosRepositoryProvider);
              cursos = await MoodleCursosApi().getCursos();
              if (cursos.isEmpty) {
                throw const FormatException(
                  'Moodle no devolvió cursos para importar.',
                );
              }
              return repository.upsertCursosConResultado(cursos);
            },
            refrescar: () async {
              container.invalidate(cursosProvider);
              container.invalidate(cargasDeHorasCRMProvider);
              container.invalidate(cargasDashboardProvider);
              container.invalidate(certificacionesMoodleProvider);
              await Future.wait([
                container.read(cursosProvider.future),
                container.read(cargasDeHorasCRMProvider.future),
                container.read(cargasDashboardProvider.future),
                container.read(certificacionesMoodleProvider.future),
              ]);
            },
          );
      if (!mounted) return;
      setState(() => _cursosMoodle = cursos);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se sincronizaron ${cursos.length} cursos.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _errorCursosMoodle = error.message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on TimeoutException {
      if (!mounted) return;
      const message = 'La consulta a Moodle agotó el tiempo.';
      setState(() => _errorCursosMoodle = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (error) {
      if (!mounted) return;
      final message = 'No se pudo completar la sincronización: $error';
      setState(() => _errorCursosMoodle = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _sincronizandoCursos = false);
    }
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
            key: const Key('importar_horas'),
            onPressed: _importacionesEnCurso.contains('horas')
                ? null
                : _importarCargaDeHoras,
            icon: _iconoImportacion('horas'),
            label: const Text('Cargar horas'),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionCargaLms(BuildContext context) {
    return _ConfigCard(
      titulo: 'Certificaciones LMS',
      subtitulo: 'Importá el estado y la fecha de finalización desde Moodle',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: Color(0xFF15803D),
            ),
          ),
          title: const Text(
            'Importar certificaciones LMS desde Excel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'ID empleado, nombre del curso, finalización y fecha',
          ),
          trailing: OutlinedButton.icon(
            key: const Key('importar_finalizaciones'),
            onPressed: _importacionesEnCurso.contains('finalizaciones')
                ? null
                : _importarCertificacionesMoodle,
            icon: _iconoImportacion('finalizaciones'),
            label: const Text('Cargar Excel'),
          ),
        ),
      ],
    );
  }

  Future<void> _importarCertificacionesMoodle() async {
    if (!_iniciarImportacion('finalizaciones')) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await WidgetsBinding.instance.endOfFrame;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      final certificaciones = <CertificacionMoodle>[];
      await container
          .read(importacionServiceProvider)
          .ejecutar(
            tipoArchivo: 'finalizaciones',
            nombreArchivo: result.files.single.name,
            procesar: () async {
              final rowsPorHoja = _leerExcel(result.files.single.bytes!);
              for (final rows in rowsPorHoja.values) {
                if (rows.length < 2) continue;
                final headerIndex = _buscarFilaCertificacionesMoodle(rows);
                if (headerIndex == -1) continue;
                final headers = rows[headerIndex]
                    .map((header) => _normalize(header.toString()))
                    .toList();
                final legajoIndex = _buscarColumna(headers, const [
                  'idempleadolegajo',
                  'idempleado',
                  'nlegajo',
                  'legajo',
                ]);
                final cursoIndex = _buscarColumna(headers, const [
                  'nombredelcurso',
                  'nombrecurso',
                  'coursename',
                  'coursefullname',
                  'fullname',
                  'curso',
                ]);
                final finalizoIndex = _buscarColumna(headers, const [
                  'finalizoelcurso',
                  'finalizocurso',
                  'completado',
                  'completed',
                ]);
                final fechaFinalizacionIndex = _buscarColumna(headers, const [
                  'fechadefinalizacion',
                  'fechafinalizacion',
                  'completiondate',
                  'datecompleted',
                  'timecompleted',
                ]);
                if (fechaFinalizacionIndex == -1) {
                  throw const FormatException(
                    'Falta la columna Fecha de finalización en el Excel de Moodle.',
                  );
                }
                for (final row in rows.skip(headerIndex + 1)) {
                  if ([
                    legajoIndex,
                    cursoIndex,
                    finalizoIndex,
                    fechaFinalizacionIndex,
                  ].any((index) => index < 0 || index >= row.length)) {
                    continue;
                  }
                  final legajo = row[legajoIndex].toString().trim();
                  final cursoNombre = row[cursoIndex].toString().trim();
                  final finalizo = _booleanoMoodle(
                    row[finalizoIndex].toString(),
                  );
                  final fechaFinalizacion = _fechaMoodle(
                    row[fechaFinalizacionIndex].toString(),
                  );
                  if (row[fechaFinalizacionIndex]
                          .toString()
                          .trim()
                          .isNotEmpty &&
                      fechaFinalizacion == null) {
                    throw FormatException(
                      'Fecha de finalización inválida para el legajo $legajo: ${row[fechaFinalizacionIndex]}.',
                    );
                  }
                  if (legajo.isEmpty ||
                      cursoNombre.isEmpty ||
                      finalizo == null) {
                    continue;
                  }
                  if (finalizo && fechaFinalizacion == null) {
                    throw FormatException(
                      'Falta una fecha de finalización válida para el legajo $legajo y el curso $cursoNombre.',
                    );
                  }
                  certificaciones.add(
                    CertificacionMoodle(
                      legajo: legajo,
                      cursoNombre: cursoNombre,
                      finalizoCurso: finalizo,
                      fechaFinalizacion: fechaFinalizacion,
                    ),
                  );
                }
              }

              if (certificaciones.isEmpty) {
                throw const FormatException(
                  'No se encontraron filas LMS válidas en el Excel.',
                );
              }
              return container
                  .read(certificacionesMoodleRepositoryProvider)
                  .upsertCertificacionesConResultado(certificaciones);
            },
            refrescar: () async {
              container.invalidate(certificacionesMoodleProvider);
              await Future.wait([
                container.read(certificacionesMoodleProvider.future),
              ]);
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se importaron ${certificaciones.length} certificaciones LMS.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar el archivo: $error')),
      );
    } finally {
      _terminarImportacion('finalizaciones');
    }
  }

  int _buscarFilaCertificacionesMoodle(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => _normalize(cell.toString()))
          .toList();
      if (_buscarColumna(headers, const [
                'idempleadolegajo',
                'idempleado',
                'nlegajo',
                'legajo',
              ]) !=
              -1 &&
          _buscarColumna(headers, const [
                'nombredelcurso',
                'nombrecurso',
                'coursename',
                'coursefullname',
                'fullname',
                'curso',
              ]) !=
              -1 &&
          _buscarColumna(headers, const [
                'finalizoelcurso',
                'finalizocurso',
                'completado',
                'completed',
              ]) !=
              -1 &&
          _buscarColumna(headers, const [
                'fechadefinalizacion',
                'fechafinalizacion',
                'completiondate',
                'datecompleted',
                'timecompleted',
              ]) !=
              -1) {
        return index;
      }
    }
    return -1;
  }

  bool? _booleanoMoodle(String value) {
    return switch (_normalize(value)) {
      'true' || 'verdadero' || 'si' || 's' || '1' || 'yes' || 'y' => true,
      'false' ||
      'falso' ||
      'no' ||
      'n' ||
      '0' ||
      'incompleto' ||
      'pendiente' => false,
      _ => null,
    };
  }

  DateTime? _fechaMoodle(String value) => fechaImportacion(value);

  Future<void> _importarArchivo() async {
    if (!_iniciarImportacion('nomina')) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await WidgetsBinding.instance.endOfFrame;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      var registrosImportados = 0;
      await container
          .read(importacionServiceProvider)
          .ejecutar(
            tipoArchivo: 'nomina',
            nombreArchivo: result.files.single.name,
            procesar: () async {
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
              final empleadosRepository = container.read(
                empleadosRepositoryProvider,
              );
              final cursosRepository = container.read(cursosRepositoryProvider);
              final cargaDeHorasRepository = container.read(
                cargaDeHorasCRMRepositoryProvider,
              );

              var empleadosImportados = <Empleado>[];
              var cursosImportados = <Curso>[];
              var cargasDeHorasImportadas = <CargaDeHorasCRM>[];
              final empleadosValidados = <String, String>{};

              for (final hoja in rowsPorHoja.entries) {
                final rows = hoja.value;
                if (!rows.any(_filaConDatos)) continue;
                final headerIndex = _buscarFilaEncabezados(rows);
                if (headerIndex == -1) {
                  throw FormatException(
                    'No se reconocen los encabezados de nómina en la hoja "${hoja.key}". No se sincronizó la nómina.',
                  );
                }
                final headers = rows[headerIndex]
                    .map((header) => _normalize(header.toString()))
                    .toList();
                _validarEncabezadosMaestro(headers, hoja.key);
                final seniorityIndex = _buscarColumnaSeniority(
                  headers,
                  rows,
                  headerIndex,
                );
                if (seniorityIndex == -1 ||
                    _buscarColumna(headers, const [
                          'fechadeingreso',
                          'fechaingreso',
                        ]) ==
                        -1) {
                  throw FormatException(
                    'Faltan las columnas Seniority o Fecha de ingreso en la hoja "${hoja.key}".',
                  );
                }

                for (var fila = headerIndex + 1; fila < rows.length; fila++) {
                  final row = rows[fila];
                  if (!_filaConDatos(row)) continue;
                  final ubicacion = 'hoja "${hoja.key}", fila ${fila + 1}';
                  _validarColumnasFila(row, headers, ubicacion);
                  final normalizedData = <String, String>{};
                  for (
                    var index = 0;
                    index < headers.length && index < row.length;
                    index++
                  ) {
                    normalizedData[headers[index]] = row[index]
                        .toString()
                        .trim();
                  }
                  if ((headers.contains('legajo') ||
                          headers.contains('nlegajo') ||
                          headers.contains('idempleado')) &&
                      (headers.contains('nombre') ||
                          headers.contains('nombreyapellido'))) {
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
                      'fechadeingreso': 'fechaIngreso',
                      'fechaingreso': 'fechaIngreso',
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
                    if (empleadoData['legajo']?.toString().trim().isEmpty ??
                        true) {
                      throw FormatException('Falta el legajo en $ubicacion.');
                    }
                    if (empleadoData['nombre']?.toString().trim().isEmpty ??
                        true) {
                      throw FormatException('Falta el nombre en $ubicacion.');
                    }
                    final seniorityTexto = seniorityIndex < row.length
                        ? row[seniorityIndex].toString().trim()
                        : '';
                    empleadoData['seniority'] = _seniorityDesdeTexto(
                      seniorityTexto,
                      ubicacion,
                    ).name;
                    final fechaIngreso = empleadoData['fechaIngreso']
                            ?.toString() ??
                        '';
                    final fecha = fechaImportacion(fechaIngreso);
                    if (fecha == null) {
                      throw FormatException(
                        'Fecha de ingreso inválida en $ubicacion: "$fechaIngreso".',
                      );
                    }
                    empleadoData['fechaIngreso'] = fecha.toIso8601String();
                    final empleado = Empleado.fromJson(empleadoData);
                    _validarDuplicadoMaestro(
                      empleadosValidados,
                      empleado.legajo,
                      empleado.toJson(),
                      'legajo',
                      ubicacion,
                    );
                    empleadosImportados = _reemplazarPorId(
                      empleadosImportados,
                      empleado,
                      (item) => item.legajo,
                    );
                  } else if ((headers.contains('cursonombre') ||
                          headers.contains('nombrecurso') ||
                          headers.contains('curso')) &&
                      headers.contains('empleadolegajo')) {
                    final cargaData = _toCanonicalKeys(normalizedData, {
                      'cursonombre': 'cursoNombre',
                      'nombrecurso': 'cursoNombre',
                      'curso': 'cursoNombre',
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

              var resumen = ResultadoUpsert.empty;
              // Leandro: llama a la sincronización de nómina para actualizar la foto vigente solo después de validar el archivo completo.
              resumen += await empleadosRepository
                  .sincronizarFotoVigenteConResultado(empleadosImportados);
              resumen += await cursosRepository.upsertCursosConResultado(
                cursosImportados,
              );
              resumen += await cargaDeHorasRepository
                  .upsertCargasDeHorasConResultado(cargasDeHorasImportadas);
              return ResultadoUpsert(
                registrosProcesados: registrosImportados,
                insertados: resumen.insertados,
                actualizados: resumen.actualizados,
              );
            },
            refrescar: () async {
              container.invalidate(empleadosProvider);
              container.invalidate(empleadoHistorialProvider);
              container.invalidate(cursosProvider);
              container.invalidate(cargasDeHorasCRMProvider);
              container.invalidate(cargasDashboardProvider);
              container.invalidate(certificacionesMoodleProvider);
              await Future.wait([
                container.read(empleadosProvider.future),
                container.read(empleadoHistorialProvider.future),
                container.read(cursosProvider.future),
                container.read(cargasDeHorasCRMProvider.future),
                container.read(cargasDashboardProvider.future),
                container.read(certificacionesMoodleProvider.future),
              ]);
            },
          );
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
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar el archivo: $error')),
      );
    } finally {
      _terminarImportacion('nomina');
    }
  }

  Future<void> _importarCursosArchivo() async {
    if (_cursosOcupados || !_iniciarImportacion('cursos')) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await WidgetsBinding.instance.endOfFrame;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      final cursosImportados = <Curso>[];
      await container
          .read(importacionServiceProvider)
          .ejecutar(
            tipoArchivo: 'cursos_lms',
            nombreArchivo: result.files.single.name,
            procesar: () async {
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
              final repository = container.read(cursosRepositoryProvider);
              final cursosValidados = <String, String>{};

              for (final hoja in rowsPorHoja.entries) {
                final rows = hoja.value;
                if (!rows.any(_filaConDatos)) continue;
                final headerIndex = _buscarFilaCursos(rows);
                if (headerIndex == -1) {
                  throw FormatException(
                    'No se encontraron cursos con encabezados válidos en la hoja "${hoja.key}". No se sincronizó el catálogo.',
                  );
                }
                final headers = rows[headerIndex]
                    .map((header) => _normalize(header.toString()))
                    .toList();
                _validarEncabezadosMaestro(headers, hoja.key);
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
                if ([idIndex, nombreIndex, tipoIndex, horasIndex]
                    .any((index) => index == -1)) {
                  throw FormatException(
                    'Faltan columnas obligatorias de ID, nombre, tipo o carga horaria en la hoja "${hoja.key}".',
                  );
                }

                for (var fila = headerIndex + 1; fila < rows.length; fila++) {
                  final row = rows[fila];
                  if (!_filaConDatos(row)) continue;
                  final ubicacion = 'hoja "${hoja.key}", fila ${fila + 1}';
                  _validarColumnasFila(row, headers, ubicacion);
                  if ([idIndex, nombreIndex, tipoIndex, horasIndex]
                      .any((index) => index >= row.length)) {
                    throw FormatException(
                      'Faltan datos obligatorios del curso en $ubicacion.',
                    );
                  }
                  final id = row[idIndex].toString().trim();
                  final nombre = row[nombreIndex].toString().trim();
                  if (id.isEmpty || nombre.isEmpty) {
                    throw FormatException(
                      'Falta el ID o nombre del curso en $ubicacion.',
                    );
                  }
                  final horasTexto = row[horasIndex].toString().trim();
                  final horas = double.tryParse(horasTexto.replaceAll(',', '.'));
                  if (horas == null || !horas.isFinite || horas < 0) {
                    throw FormatException(
                      'Carga horaria inválida en $ubicacion: "$horasTexto".',
                    );
                  }
                  final curso = Curso(
                    id: id,
                    nombre: nombre,
                    tipo: _tipoCursoDesdeTexto(
                      row[tipoIndex].toString(),
                      ubicacion,
                    ),
                    areaCurso: '',
                    instructorLegajo: '',
                    cargaHorariaHs: horas,
                  );
                  _validarDuplicadoMaestro(
                    cursosValidados,
                    curso.id,
                    curso.toJson(),
                    'ID de curso',
                    ubicacion,
                  );
                  cursosImportados.add(curso);
                }
              }

              if (cursosImportados.isEmpty) {
                throw const FormatException(
                  'No se encontraron cursos. Verificá las columnas de ID y nombre.',
                );
              }
              // Leandro: llama a la sincronización del catálogo para dar altas, bajas y reactivaciones después de validar todas las hojas.
              return repository.sincronizarFotoVigenteConResultado(
                cursosImportados,
              );
            },
            refrescar: () async {
              container.invalidate(cursosProvider);
              container.invalidate(cargasDeHorasCRMProvider);
              container.invalidate(cargasDashboardProvider);
              container.invalidate(certificacionesMoodleProvider);
              await Future.wait([
                container.read(cursosProvider.future),
                container.read(cargasDeHorasCRMProvider.future),
                container.read(cargasDashboardProvider.future),
                container.read(certificacionesMoodleProvider.future),
              ]);
            },
          );
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
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar el archivo: $error')),
      );
    } finally {
      _terminarImportacion('cursos');
    }
  }

  Future<void> _importarCargaDeHoras() async {
    if (!_iniciarImportacion('horas')) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await WidgetsBinding.instance.endOfFrame;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      final cargasImportadas = <CargaDeHorasCRM>[];
      await container
          .read(importacionServiceProvider)
          .ejecutar(
            tipoArchivo: 'horas_crm',
            nombreArchivo: result.files.single.name,
            procesar: () async {
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
              final repository = container.read(
                cargaDeHorasCRMRepositoryProvider,
              );
              final cursosRepository = container.read(cursosRepositoryProvider);
              final cursosPorNombre = <String, Curso>{};

              var encabezadoReconocido = false;

              for (final rows in rowsPorHoja.values) {
                if (rows.length < 2) continue;
                final headerIndex = _buscarFilaCargaDeHoras(rows);
                if (headerIndex == -1) continue;
                encabezadoReconocido = true;
                final headers = rows[headerIndex]
                    .map((header) => _normalize(header.toString()))
                    .toList();
                final idIndex = _buscarColumnaCRM(headers, 'id');
                final legajoIndex = _buscarColumnaCRM(headers, 'legajo');
                final fechaIndex = _buscarColumnaCRM(headers, 'fecha');
                final cursoIndex = headers.indexOf('curso');
                final horasIndex = _buscarColumnaCRM(headers, 'horas');
                if ([
                  idIndex,
                  legajoIndex,
                  fechaIndex,
                  cursoIndex,
                  horasIndex,
                ].any((index) => index == -1)) {
                  continue;
                }

                for (final row in rows.skip(headerIndex + 1)) {
                  if (row.every((cell) => cell.toString().trim().isEmpty)) {
                    continue;
                  }
                  if ([
                    idIndex,
                    legajoIndex,
                    fechaIndex,
                    cursoIndex,
                    horasIndex,
                  ].any((index) => index >= row.length)) {
                    throw const FormatException(
                      'Fila CRM incompleta: faltan columnas obligatorias.',
                    );
                  }
                  final nombreCurso = row[cursoIndex].toString().trim();
                  final curso =
                      cursosPorNombre[normalizarNombreCurso(
                        nombreCurso,
                      )] ??= resolverCurso(
                        nombreCurso,
                        await cursosRepository.getCursos(nombre: nombreCurso),
                      );
                  final fecha = _fechaDesdeCelda(row[fechaIndex].toString());
                  String? fuente(String campo) {
                    final index = headers.indexOf(campo);
                    return index < 0 || index >= row.length
                        ? null
                        : row[index].toString().trim();
                  }

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
                      cursoNombre: curso.nombre,
                      cursoId: curso.id,
                      caso: fuente('caso'),
                      descripcionCurso: fuente('descripcioncurso'),
                      clasificacion: fuente('clasificacion'),
                      proyecto: fuente('proyecto'),
                      proyectoItem: fuente('proyectoitem'),
                      descripcion: fuente('descripcion'),
                      empleadoLegajo: legajo,
                      fecha: fecha,
                      horasTotales: horas,
                      tipo: TipoCargaDeHoras.tomada,
                    ),
                  );
                }
              }

              if (cargasImportadas.isEmpty) {
                if (!encabezadoReconocido) {
                  throw const FormatException(
                    'No se reconocieron los encabezados. El Excel debe incluir ID de transacción, legajo, fecha, curso y horas total.',
                  );
                }
                throw const FormatException(
                  'El archivo no tiene registros CRM válidos.',
                );
              }
              return repository.upsertCargasDeHorasConResultado(
                cargasImportadas,
              );
            },
            refrescar: () async {
              container.invalidate(cargasDeHorasCRMProvider);
              container.invalidate(cargasDashboardProvider);
              await Future.wait([
                container.read(cargasDeHorasCRMProvider.future),
                container.read(cargasDashboardProvider.future),
              ]);
            },
          );
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
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar el archivo: $error')),
      );
    } finally {
      _terminarImportacion('horas');
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
          headers.contains('curso') &&
          _buscarColumnaCRM(headers.toList(), 'fecha') != -1 &&
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
        'horas' => header.contains('hora') && header.contains('total'),
        _ => false,
      };
      if (coincide) return index;
    }
    return -1;
  }

  DateTime _fechaDesdeCelda(String value) => fechaObligatoria(value);

  int _buscarColumna(List<String> headers, List<String> posibles) {
    for (final posible in posibles) {
      final index = headers.indexOf(posible);
      if (index != -1) return index;
    }
    return -1;
  }

  TipoCurso _tipoCursoDesdeTexto(String value, String ubicacion) {
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
    if (normalized.contains('libre') ||
        normalized.contains('exploracion') ||
        normalized.contains('profundizacion')) {
      return TipoCurso.libresExploracion;
    }
    throw FormatException('Tipo de curso inválido en $ubicacion: "$value".');
  }

  bool _filaConDatos(List<dynamic> row) =>
      row.any((cell) => cell.toString().trim().isNotEmpty);

  void _validarEncabezadosMaestro(List<String> headers, String hoja) {
    final vistos = <String>{};
    for (final header in headers.where((header) => header.isNotEmpty)) {
      if (!vistos.add(header)) {
        throw FormatException(
          'Encabezado duplicado "$header" en la hoja "$hoja".',
        );
      }
    }
  }

  void _validarColumnasFila(
    List<dynamic> row,
    List<String> headers,
    String ubicacion,
  ) {
    for (var index = 0; index < row.length; index++) {
      if (row[index].toString().trim().isEmpty) continue;
      if (index >= headers.length || headers[index].isEmpty) {
        throw FormatException(
          'Hay datos sin encabezado de columna en $ubicacion.',
        );
      }
    }
  }

  void _validarDuplicadoMaestro(
    Map<String, String> validados,
    String id,
    Map<String, dynamic> data,
    String campo,
    String ubicacion,
  ) {
    final contenido = jsonEncode(data);
    final anterior = validados[id];
    if (anterior != null && anterior != contenido) {
      throw FormatException(
        'El $campo "$id" tiene datos contradictorios en $ubicacion.',
      );
    }
    validados[id] = contenido;
  }

  Seniority _seniorityDesdeTexto(String value, String ubicacion) {
    final normalized = _normalize(value);
    final configurado = Seniority.values.any(
      (seniority) => _normalize(seniority.name) == normalized ||
          _normalize(seniority.label) == normalized,
    );
    final aliasValido = RegExp(
      r'^trainee(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)?$|^t$'
      r'|^(?:junior|jr|j|senior|senor|sr|s)(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)?$'
      r'|^(?:semisenior|semisenor|ssr|ss)(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)$'
      r'|^(?:manager|gerente|m)$',
    ).hasMatch(normalized);
    if (!configurado && !aliasValido) {
      throw FormatException('Seniority inválido en $ubicacion: "$value".');
    }
    return Seniority.fromString(value);
  }

  bool _esColumnaSeniority(String header) {
    return header == 'seniority' ||
        header == 'senority' ||
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
      'senority',
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
