import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_finnegans/data/formacion_repository.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/cursada.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/cursadas_providers.dart';
import 'package:app_finnegans/presentation/providers/cursos_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';

class ConfiguracionScreen extends ConsumerStatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  ConsumerState<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends ConsumerState<ConfiguracionScreen> {
  static const _trimestreKey = 'config_trimestre';
  static const _horasKey = 'config_horas_base';
  static const _usarMockKey = 'config_usar_mock';

  String _trimestre = 'Q3';
  double _horasBase = 8;
  bool _usarMock = true;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _trimestre = preferences.getString(_trimestreKey) ?? 'Q3';
      _horasBase = preferences.getDouble(_horasKey) ?? 8;
      _usarMock = preferences.getBool(_usarMockKey) ?? true;
      _cargando = false;
    });
  }

  Future<void> _guardarConfiguracion() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_trimestreKey, _trimestre);
    await preferences.setDouble(_horasKey, _horasBase);
    await preferences.setBool(_usarMockKey, _usarMock);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
                        child: const Text('U', style: TextStyle(color: Colors.white)),
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
                      _buildSeccionPlan(),
                      const SizedBox(height: 24),
                      _buildSeccionEntorno(),
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
      titulo: 'Carga e Integración de Datos',
      subtitulo: 'Seleccioná el método para ingresar o sincronizar los registros',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.table_chart_outlined, color: Color(0xFF1D4ED8)),
          ),
          title: const Text('Importar desde Excel / CSV', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Subí planillas Excel o CSV con empleados, cursos y cursadas'),
          trailing: OutlinedButton.icon(
            onPressed: _importarArchivo,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Subir Archivo'),
          ),
        ),
        const Divider(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.link, color: Color(0xFF047857)),
          ),
          title: const Text('Vincular Google Sheets', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Sincronización automática con la hoja de cálculo de Formación'),
          trailing: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D53C3)),
            child: const Text('Conectar'),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionPlan() {
    return _ConfigCard(
      titulo: 'Parámetros del Plan de Formación',
      subtitulo: 'Ajustá las bases de cálculo del período actual',
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _trimestre,
                decoration: const InputDecoration(
                  labelText: 'Trimestre Activo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'Q1', child: Text('Q1 (Ene - Mar)')),
                  DropdownMenuItem(value: 'Q2', child: Text('Q2 (Abr - Jun)')),
                  DropdownMenuItem(value: 'Q3', child: Text('Q3 (Jul - Sep)')),
                  DropdownMenuItem(value: 'Q4', child: Text('Q4 (Oct - Dic)')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _trimestre = value);
                  _guardarConfiguracion();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: _horasBase.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Carga Base Requerida (Horas)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixText: 'hs',
                ),
                onChanged: (value) {
                  final horas = double.tryParse(value.replaceAll(',', '.'));
                  if (horas == null || horas < 0) return;
                  _horasBase = horas;
                  _guardarConfiguracion();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeccionEntorno() {
    return _ConfigCard(
      titulo: 'Estado de la Base de Datos',
      subtitulo: 'Control de persistencia y datos de desarrollo',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Utilizar Datos Simulados (Mock Repository)', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Desactivá esta opción cuando conectes la API o SQLite'),
          value: _usarMock,
          activeThumbColor: const Color(0xFF0D53C3),
          onChanged: (value) {
            setState(() => _usarMock = value);
            _guardarConfiguracion();
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _restablecerDatos,
              icon: const Icon(Icons.refresh, color: Color(0xFFDC2626)),
              label: const Text('Restablecer Datos Mock', style: TextStyle(color: Color(0xFFDC2626))),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _restablecerDatos() async {
    await ref.read(formacionRepositoryProvider).resetToMock();
    ref.invalidate(empleadosProvider);
    ref.invalidate(cursosProvider);
    ref.invalidate(cursadasProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Se restablecieron los datos simulados.')),
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
                  .convert(utf8.decode(result.files.single.bytes!).replaceFirst('\ufeff', '')),
            };
      final repository = ref.read(formacionRepositoryProvider);
      if (repository is! LocalFormacionRepository) {
        throw const FormatException('El repositorio local no está disponible.');
      }

      final empleados = await repository.getEmpleados();
      final cursos = await repository.getCursos();
      final cursadas = await repository.getCursadas();
      var empleadosImportados = [...empleados];
      var cursosImportados = [...cursos];
      var cursadasImportadas = [...cursadas];
      var empleadosReemplazados = false;
      var cursosReemplazados = false;
      var cursadasReemplazadas = false;

      var registrosImportados = 0;
      for (final rows in rowsPorHoja.values) {
        if (rows.length < 2) continue;
        final headerIndex = _buscarFilaEncabezados(rows);
        if (headerIndex == -1) continue;
        final headers = rows[headerIndex].map((header) => _normalize(header.toString())).toList();
        final seniorityIndex = _buscarColumnaSeniority(headers);
        final records = rows.skip(headerIndex + 1).where((row) => row.any((cell) => cell.toString().trim().isNotEmpty));

        for (final row in records) {
          final normalizedData = <String, String>{};
          for (var index = 0; index < headers.length && index < row.length; index++) {
            normalizedData[headers[index]] = row[index].toString().trim();
          }
            if ((headers.contains('legajo') || headers.contains('nlegajo') || headers.contains('idempleado')) &&
              (headers.contains('nombre') || headers.contains('nombreyapellido'))) {
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
              empleadoData['seniority'] = row[seniorityIndex].toString().trim();
            }
            final empleado = Empleado.fromJson(empleadoData);
            empleadosImportados = _reemplazarPorId(empleadosImportados, empleado, (item) => item.legajo);
          } else if (headers.contains('cursoid') && headers.contains('empleadolegajo')) {
            if (!cursadasReemplazadas) {
              cursadasImportadas = [];
              cursadasReemplazadas = true;
            }
            final cursada = Cursada.fromJson(_toCanonicalKeys(normalizedData, {
              'cursoid': 'cursoId',
              'empleadolegajo': 'empleadoLegajo',
            }));
            cursadasImportadas = _reemplazarPorId(cursadasImportadas, cursada, (item) => item.id);
          } else if (headers.contains('id') && headers.contains('nombre') && headers.contains('tipo')) {
            if (!cursosReemplazados) {
              cursosImportados = [];
              cursosReemplazados = true;
            }
            final curso = Curso.fromJson(_toCanonicalKeys(normalizedData, {
              'areacurso': 'areaCurso',
              'instructorlegajo': 'instructorLegajo',
              'cargahorariahs': 'cargaHorariaHs',
            }));
            cursosImportados = _reemplazarPorId(cursosImportados, curso, (item) => item.id);
          } else {
            throw FormatException('Encabezados no reconocidos en una hoja del archivo.');
          }
          registrosImportados++;
        }
      }
      if (registrosImportados == 0) throw const FormatException('El archivo no tiene registros.');

      await repository.replaceData(
        empleados: empleadosImportados,
        cursos: cursosImportados,
        cursadas: cursadasImportadas,
      );
      ref.invalidate(empleadosProvider);
      ref.invalidate(cursosProvider);
      ref.invalidate(cursadasProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se importaron $registrosImportados registros desde ${result.files.single.name}.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo CSV.')),
      );
    }
  }

  Map<String, List<List<dynamic>>> _leerExcel(List<int> bytes) {
    final workbook = Excel.decodeBytes(bytes);
    return {
      for (final entry in workbook.tables.entries)
        entry.key: entry.value.rows
            .map((row) => row.map((cell) => cell?.value ?? '').toList())
            .toList(),
    };
  }

  List<T> _reemplazarPorId<T>(List<T> actuales, T nuevo, String Function(T) id) {
    final index = actuales.indexWhere((item) => id(item) == id(nuevo));
    if (index == -1) return [...actuales, nuevo];
    final resultado = [...actuales]..[index] = nuevo;
    return resultado;
  }

  int _buscarFilaEncabezados(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index].map((cell) => _normalize(cell.toString())).toSet();
      if ((headers.contains('legajo') || headers.contains('nlegajo') || headers.contains('idempleado')) &&
          (headers.contains('nombre') || headers.contains('nombreyapellido'))) {
        return index;
      }
    }
    return -1;
  }

  bool _esColumnaSeniority(String header) {
    return header.contains('senior') ||
        header.contains('nivel') ||
        header.contains('categoria') ||
        header.contains('grado') ||
        header.contains('jerarquia');
  }

  int _buscarColumnaSeniority(List<String> headers) {
    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      if (_esColumnaSeniority(header)) return index;
    }
    return -1;
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
      for (final entry in data.entries) aliases[entry.key] ?? entry.key: entry.value,
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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