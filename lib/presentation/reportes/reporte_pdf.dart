import 'package:app_finnegans/core/theme/colores_reporte_pdf.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/comparacion_moodle_crm.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Semáforo de una fila del reporte, ya resuelto por la pantalla que lo arma.
enum NivelReporte {
  ok,
  atencion,
  critico;

  /// Mismos cortes que el semáforo de la app.
  static NivelReporte desdePorcentaje(double porcentaje) => porcentaje >= 100
      ? NivelReporte.ok
      : porcentaje >= 70
      ? NivelReporte.atencion
      : NivelReporte.critico;
}

/// Una fila del desglose: áreas en el general, equipos en el de área.
class FilaDesgloseReporte {
  final String nombre;
  final int integrantes;
  final double horas;
  final double objetivo;
  final double porcentaje;
  final String estado;
  final NivelReporte nivel;

  const FilaDesgloseReporte({
    required this.nombre,
    required this.integrantes,
    required this.horas,
    required this.objetivo,
    required this.porcentaje,
    required this.estado,
    required this.nivel,
  });
}

/// Todo lo que muestra el reporte, con los mismos números que la pantalla.
class ReporteFormacion {
  /// "Reporte general", "Reporte de área", "Reporte de equipo".
  final String tipo;
  final String titulo;

  /// Líneas cortas bajo el título: área, líder, etc.
  final List<String> detalles;
  final String periodo;

  final int integrantes;
  final int enObjetivo;
  final double horas;
  final double objetivo;
  final double porcentaje;
  final String estado;
  final NivelReporte nivel;

  final ProyeccionAnual? proyeccion;
  final List<CumplimientoEmpleado> miembros;

  final String? desgloseTitulo;
  final List<FilaDesgloseReporte> desglose;

  /// Horas válidas por persona de los últimos meses (solo el general).
  final List<({DateTime mes, double horas})> evolucion;

  /// En el general la nómina es larga: se listan solo los críticos.
  final bool soloCriticos;

  /// Muestra la columna Equipo en la tabla de integrantes.
  final bool mostrarEquipo;

  const ReporteFormacion({
    required this.tipo,
    required this.titulo,
    this.detalles = const [],
    required this.periodo,
    required this.integrantes,
    required this.enObjetivo,
    required this.horas,
    required this.objetivo,
    required this.porcentaje,
    required this.estado,
    required this.nivel,
    this.proyeccion,
    required this.miembros,
    this.desgloseTitulo,
    this.desglose = const [],
    this.evolucion = const [],
    this.soloCriticos = false,
    this.mostrarEquipo = false,
  });

  String get nombreArchivo {
    final base = '$tipo $titulo $periodo'
        .toLowerCase()
        .replaceAll(RegExp(r'[áà]'), 'a')
        .replaceAll(RegExp(r'[éè]'), 'e')
        .replaceAll(RegExp(r'[íì]'), 'i')
        .replaceAll(RegExp(r'[óò]'), 'o')
        .replaceAll(RegExp(r'[úù]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '$base.pdf';
  }
}

/// Abre el diálogo de impresión del navegador o del sistema con el reporte,
/// desde donde también se puede guardar como PDF.
Future<void> imprimirReporte(ReporteFormacion reporte) async {
  // Se genera antes de abrir el diálogo, así un error llega a quien llamó.
  final bytes = await generarReportePdf(reporte);
  await Printing.layoutPdf(
    name: reporte.nombreArchivo,
    format: PdfPageFormat.a4,
    onLayout: (_) async => bytes,
  );
}

Future<Uint8List> generarReportePdf(ReporteFormacion reporte) async {
  final e = await _EstiloReporte.cargar();
  final doc = pw.Document(
    title: '${reporte.tipo} · ${reporte.titulo}',
    author: 'Finnegans · Formación interna',
  );
  final generado = DateTime.now();

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
        theme: pw.ThemeData.withFont(
          base: e.regular,
          bold: e.bold,
        ).copyWith(defaultTextStyle: pw.TextStyle(fontSize: 9, color: _tinta)),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _encabezadoCorto(reporte, e),
      footer: (context) => _pie(context, generado),
      // Los bloques cortos no se parten entre páginas; las tablas largas sí,
      // repitiendo su encabezado.
      build: (context) => [
        _portada(reporte, e, generado),
        pw.SizedBox(height: 16),
        pw.Inseparable(child: _kpis(reporte, e)),
        pw.SizedBox(height: 18),
        pw.Inseparable(child: _estadoPersonas(reporte, e)),
        pw.SizedBox(height: 18),
        pw.Inseparable(child: _categorias(reporte, e)),
        pw.SizedBox(height: 18),
        pw.Inseparable(child: _fuentes(reporte, e)),
        if (reporte.evolucion.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          pw.Inseparable(child: _evolucion(reporte, e)),
        ],
        if (reporte.desglose.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          ..._desglose(reporte, e),
        ],
        pw.SizedBox(height: 18),
        ..._integrantes(reporte, e),
        pw.SizedBox(height: 14),
        pw.Inseparable(child: _notas()),
      ],
    ),
  );
  return doc.save();
}

// ---------------------------------------------------------------------------
// Paleta en lib/core/theme/colores_reporte_pdf.dart.

const _tinta = ColoresReportePdf.tinta;
const _tintaSuave = ColoresReportePdf.tintaSuave;
const _linea = ColoresReportePdf.linea;
const _fondoSuave = ColoresReportePdf.fondoSuave;
const _marca = ColoresReportePdf.marca;
const _marcaFondo = ColoresReportePdf.marcaFondo;
const _pista = ColoresReportePdf.pista;
const _colorCategoria = ColoresReportePdf.categoria;

const _colorNivel = {
  NivelReporte.ok: ColoresReportePdf.ok,
  NivelReporte.atencion: ColoresReportePdf.atencion,
  NivelReporte.critico: ColoresReportePdf.critico,
};
const _fondoNivel = {
  NivelReporte.ok: ColoresReportePdf.okFondo,
  NivelReporte.atencion: ColoresReportePdf.atencionFondo,
  NivelReporte.critico: ColoresReportePdf.criticoFondo,
};

const _nombreCorto = {
  TipoCurso.habilidadesDeNegocio: 'Negocio',
  TipoCurso.habilidadesBlandas: 'Blandas',
  TipoCurso.libresExploracion: 'Libres',
  TipoCurso.dictadoCapacitaciones: 'Dictado',
};

class _EstiloReporte {
  final pw.Font regular;
  final pw.Font medio;
  final pw.Font bold;
  final pw.ImageProvider? logo;

  const _EstiloReporte({
    required this.regular,
    required this.medio,
    required this.bold,
    this.logo,
  });

  static _EstiloReporte? _cache;

  /// Inter va en los assets: el reporte no depende de la red y las tildes
  /// salen siempre bien (Helvetica no tiene Unicode).
  static Future<_EstiloReporte> cargar() async {
    if (_cache != null) return _cache!;
    Future<pw.Font> fuente(String peso) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-$peso.ttf'));
    final logo = await rootBundle.load('assets/images/logo_finnegans.png');
    return _cache = _EstiloReporte(
      regular: await fuente('Regular'),
      medio: await fuente('Medium'),
      bold: await fuente('Bold'),
      logo: pw.MemoryImage(logo.buffer.asUint8List()),
    );
  }
}

String _h(double horas) => '${horas.toStringAsFixed(1)} h';
String _h0(double horas) => '${horas.toStringAsFixed(0)} h';

String _fecha(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}

// ---------------------------------------------------------------------------
// Encabezados y pie

pw.Widget _portada(ReporteFormacion r, _EstiloReporte e, DateTime generado) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (e.logo != null) ...[
            pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Image(e.logo!, width: 26, height: 26),
            ),
            pw.SizedBox(width: 8),
          ],
          pw.Text(
            'FINNEGANS · FORMACIÓN INTERNA',
            style: pw.TextStyle(
              font: e.bold,
              fontSize: 8,
              letterSpacing: 1.2,
              color: _tintaSuave,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Generado el ${_fecha(generado)}',
            style: const pw.TextStyle(fontSize: 8, color: _tintaSuave),
          ),
        ],
      ),
      pw.SizedBox(height: 18),
      pw.Text(
        r.tipo.toUpperCase(),
        style: pw.TextStyle(
          font: e.bold,
          fontSize: 9,
          letterSpacing: 1,
          color: _marca,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Text(
              r.titulo,
              style: pw.TextStyle(font: e.bold, fontSize: 22, color: _tinta),
            ),
          ),
          pw.SizedBox(width: 12),
          _chipEstado(r.estado, r.nivel, e, grande: true),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 14,
        runSpacing: 2,
        children: [
          _dato('Período', r.periodo, e),
          for (final detalle in r.detalles) _datoLibre(detalle),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Container(height: 2, color: _marca),
    ],
  );
}

pw.Widget _dato(String etiqueta, String valor, _EstiloReporte e) => pw.RichText(
  text: pw.TextSpan(
    children: [
      pw.TextSpan(
        text: '$etiqueta: ',
        style: const pw.TextStyle(color: _tintaSuave, fontSize: 9),
      ),
      pw.TextSpan(
        text: valor,
        style: pw.TextStyle(font: e.medio, fontSize: 9),
      ),
    ],
  ),
);

pw.Widget _datoLibre(String texto) =>
    pw.Text(texto, style: const pw.TextStyle(color: _tintaSuave, fontSize: 9));

pw.Widget _encabezadoCorto(ReporteFormacion r, _EstiloReporte e) =>
    pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _linea)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            '${r.tipo} · ${r.titulo}',
            style: pw.TextStyle(font: e.medio, fontSize: 8),
          ),
          pw.Spacer(),
          pw.Text(
            r.periodo,
            style: const pw.TextStyle(fontSize: 8, color: _tintaSuave),
          ),
        ],
      ),
    );

pw.Widget _pie(pw.Context context, DateTime generado) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 10),
  child: pw.Row(
    children: [
      pw.Text(
        'Plan de formación interna · uso interno',
        style: const pw.TextStyle(fontSize: 7, color: _tintaSuave),
      ),
      pw.Spacer(),
      pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 7, color: _tintaSuave),
      ),
    ],
  ),
);

// ---------------------------------------------------------------------------
// Bloques

pw.Widget _titulo(String titulo, _EstiloReporte e, {String? bajada}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(titulo, style: pw.TextStyle(font: e.bold, fontSize: 12)),
          if (bajada != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              bajada,
              style: const pw.TextStyle(fontSize: 8, color: _tintaSuave),
            ),
          ],
        ],
      ),
    );

pw.Widget _chipEstado(
  String texto,
  NivelReporte nivel,
  _EstiloReporte e, {
  bool grande = false,
}) => pw.Container(
  padding: pw.EdgeInsets.symmetric(
    horizontal: grande ? 10 : 6,
    vertical: grande ? 4 : 2,
  ),
  decoration: pw.BoxDecoration(
    color: _fondoNivel[nivel],
    borderRadius: pw.BorderRadius.circular(10),
  ),
  child: pw.Text(
    texto,
    style: pw.TextStyle(
      font: e.bold,
      fontSize: grande ? 9 : 7.5,
      color: _colorNivel[nivel],
    ),
  ),
);

pw.Widget _barra(double progreso, PdfColor color, {double alto = 5}) =>
    pw.LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints!.maxWidth;
        return pw.Stack(
          children: [
            pw.Container(
              width: ancho,
              height: alto,
              decoration: pw.BoxDecoration(
                color: _pista,
                borderRadius: pw.BorderRadius.circular(alto / 2),
              ),
            ),
            pw.Container(
              width: ancho * progreso.clamp(0.0, 1.0),
              height: alto,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.circular(alto / 2),
              ),
            ),
          ],
        );
      },
    );

pw.Widget _kpis(ReporteFormacion r, _EstiloReporte e) {
  final p = r.proyeccion;
  final faltan = (r.objetivo - r.horas).clamp(0.0, double.infinity);
  final tarjetas = <pw.Widget>[
    _kpi(
      e,
      titulo: 'INTEGRANTES',
      valor: '${r.integrantes}',
      detalle: '${r.enObjetivo} en objetivo',
      progreso: r.integrantes == 0 ? 0 : r.enObjetivo / r.integrantes,
      color: _marca,
    ),
    _kpi(
      e,
      titulo: 'HORAS VÁLIDAS',
      valor: _h(r.horas),
      detalle: 'de ${_h0(r.objetivo)} · faltan ${_h(faltan)}',
      progreso: r.objetivo == 0 ? 0 : r.horas / r.objetivo,
      color: _marca,
    ),
    _kpi(
      e,
      titulo: 'CUMPLIMIENTO',
      valor: formatearPorcentaje(r.porcentaje),
      detalle: r.estado,
      progreso: r.porcentaje / 100,
      color: _colorNivel[r.nivel]!,
      colorValor: _colorNivel[r.nivel],
    ),
    if (p != null)
      _kpi(
        e,
        titulo: 'PROYECCIÓN A DIC.',
        valor: formatearPorcentaje(p.porcentaje),
        detalle: '${p.estado.label} · ${p.llegan} de ${p.colaboradores} llegan',
        progreso: p.porcentaje / 100,
        color: switch (p.estado) {
          EstadoProyeccion.enCamino => _colorNivel[NivelReporte.ok]!,
          EstadoProyeccion.alcanzable => _colorNivel[NivelReporte.atencion]!,
          EstadoProyeccion.enRiesgo => _colorNivel[NivelReporte.critico]!,
        },
      ),
  ];
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < tarjetas.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 8),
        pw.Expanded(child: tarjetas[i]),
      ],
    ],
  );
}

pw.Widget _kpi(
  _EstiloReporte e, {
  required String titulo,
  required String valor,
  required String detalle,
  required double progreso,
  required PdfColor color,
  PdfColor? colorValor,
}) => pw.Container(
  padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 10),
  decoration: pw.BoxDecoration(
    color: _fondoSuave,
    borderRadius: pw.BorderRadius.circular(6),
    border: pw.Border.all(color: _linea),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        titulo,
        style: pw.TextStyle(
          font: e.bold,
          fontSize: 6.5,
          letterSpacing: 0.6,
          color: _tintaSuave,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        valor,
        style: pw.TextStyle(
          font: e.bold,
          fontSize: 17,
          color: colorValor ?? _tinta,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        detalle,
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 7.5, color: _tintaSuave),
      ),
      pw.SizedBox(height: 6),
      _barra(progreso, color, alto: 4),
    ],
  ),
);

pw.Widget _estadoPersonas(ReporteFormacion r, _EstiloReporte e) {
  final conteo = {for (final nivel in NivelReporte.values) nivel: 0};
  for (final miembro in r.miembros) {
    final nivel = NivelReporte.desdePorcentaje(miembro.porcentajeTotal);
    conteo[nivel] = conteo[nivel]! + 1;
  }
  final total = r.miembros.length;
  const etiquetas = {
    NivelReporte.ok: 'Cumple (100%)',
    NivelReporte.atencion: 'Atención (70 a 99%)',
    NivelReporte.critico: 'No cumple (menos de 70%)',
  };

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _titulo(
        'Estado de cumplimiento',
        e,
        bajada: 'Cómo se reparten las $total personas evaluadas en el semáforo',
      ),
      // Barra apilada: una lectura rápida de la proporción.
      pw.ClipRRect(
        horizontalRadius: 4,
        verticalRadius: 4,
        child: pw.Row(
          children: [
            for (final nivel in NivelReporte.values)
              if (conteo[nivel]! > 0)
                pw.Expanded(
                  flex: conteo[nivel]!,
                  child: pw.Container(
                    height: 14,
                    color: _colorNivel[nivel],
                    alignment: pw.Alignment.center,
                    child: conteo[nivel]! / total >= 0.08
                        ? pw.Text(
                            '${(conteo[nivel]! / total * 100).round()}%',
                            style: pw.TextStyle(
                              font: e.bold,
                              fontSize: 7,
                              color: ColoresReportePdf.blanco,
                            ),
                          )
                        : null,
                  ),
                ),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        children: [
          for (final nivel in NivelReporte.values) ...[
            pw.Container(
              width: 7,
              height: 7,
              decoration: pw.BoxDecoration(
                color: _colorNivel[nivel],
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text(etiquetas[nivel]!, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(width: 4),
            pw.Text(
              '${conteo[nivel]} (${total == 0 ? 0 : (conteo[nivel]! / total * 100).round()}%)',
              style: pw.TextStyle(font: e.bold, fontSize: 8),
            ),
            pw.SizedBox(width: 16),
          ],
        ],
      ),
    ],
  );
}

pw.Widget _categorias(ReporteFormacion r, _EstiloReporte e) {
  double suma(double Function(CumplimientoEmpleado) valor) =>
      r.miembros.fold(0, (t, m) => t + valor(m));
  final filas = [
    for (final tipo in TipoCurso.values)
      (
        tipo: tipo,
        validas: suma((m) => m.horasAplicablesAlObjetivo(tipo)),
        objetivo: suma((m) => m.horasRequeridas[tipo] ?? 0),
      ),
  ];
  final totalValidas = filas.fold<double>(0, (t, f) => t + f.validas);
  final totalObjetivo = filas.fold<double>(0, (t, f) => t + f.objetivo);

  pw.Widget fila({
    required pw.Widget nombre,
    required double validas,
    required double objetivo,
    required PdfColor color,
    bool total = false,
  }) {
    final progreso = objetivo == 0 ? 1.0 : validas / objetivo;
    final estilo = total
        ? pw.TextStyle(font: e.bold, fontSize: 8.5)
        : const pw.TextStyle(fontSize: 8.5);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: total ? _fondoSuave : null,
        border: const pw.Border(bottom: pw.BorderSide(color: _linea)),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 150, child: nombre),
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              _h(validas),
              style: estilo,
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              _h(objetivo),
              style: estilo.copyWith(color: _tintaSuave),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(child: _barra(progreso, color)),
          pw.SizedBox(
            width: 40,
            child: pw.Text(
              objetivo == 0 ? '-' : formatearPorcentaje(progreso * 100),
              style: estilo.copyWith(font: e.bold),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget encabezado(String texto, {double? ancho, bool derecha = false}) {
    final t = pw.Text(
      texto,
      textAlign: derecha ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(font: e.bold, fontSize: 7, color: _tintaSuave),
    );
    return ancho == null
        ? pw.Expanded(child: t)
        : pw.SizedBox(width: ancho, child: t);
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _titulo(
        'Horas por categoría',
        e,
        bajada:
            'Horas válidas para la meta: cada persona suma hasta su objetivo en cada categoría.',
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _tinta, width: 0.8)),
        ),
        child: pw.Row(
          children: [
            encabezado('CATEGORÍA', ancho: 150),
            encabezado('VÁLIDAS', ancho: 70, derecha: true),
            encabezado('OBJETIVO', ancho: 70, derecha: true),
            pw.SizedBox(width: 16),
            encabezado('AVANCE'),
            encabezado('%', ancho: 40, derecha: true),
          ],
        ),
      ),
      for (final f in filas)
        fila(
          nombre: pw.Row(
            children: [
              pw.Container(
                width: 7,
                height: 7,
                decoration: pw.BoxDecoration(
                  color: _colorCategoria[f.tipo],
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(f.tipo.label, style: const pw.TextStyle(fontSize: 8.5)),
            ],
          ),
          validas: f.validas,
          objetivo: f.objetivo,
          color: _colorCategoria[f.tipo]!,
        ),
      fila(
        nombre: pw.Text(
          'Total',
          style: pw.TextStyle(font: e.bold, fontSize: 8.5),
        ),
        validas: totalValidas,
        objetivo: totalObjetivo,
        color: _tinta,
        total: true,
      ),
    ],
  );
}

pw.Widget _fuentes(ReporteFormacion r, _EstiloReporte e) {
  final c = ComparacionMoodleCrm.desde(r.miembros);
  const comparables = ComparacionMoodleCrm.comparables;
  final moodle = c.totalMoodle(comparables);
  final crmComparable = c.totalCrm(comparables);
  final crmTotal = c.totalCrm(TipoCurso.values);
  final diferencia = crmComparable - moodle;

  pw.Widget celda(String texto, {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        child: pw.Text(
          texto,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            font: bold ? e.bold : e.regular,
            fontSize: 8.5,
            color: color,
          ),
        ),
      );
  pw.Widget nombre(String texto, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    child: pw.Text(
      texto,
      style: pw.TextStyle(font: bold ? e.bold : e.regular, fontSize: 8.5),
    ),
  );
  pw.Widget enc(String texto, {bool derecha = true}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    child: pw.Text(
      texto,
      textAlign: derecha ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(font: e.bold, fontSize: 7, color: _tintaSuave),
    ),
  );

  final textoDiferencia = diferencia.abs() < 0.05
      ? 'En Negocio y Blandas las dos fuentes coinciden.'
      : 'En Negocio y Blandas, CRM registra ${_h(diferencia.abs())} '
            '${diferencia > 0 ? 'más' : 'menos'} que Moodle'
            '${moodle == 0 ? '' : ' (${diferencia > 0 ? '+' : '-'}${(diferencia.abs() / moodle * 100).toStringAsFixed(0)}%)'}.';

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _titulo(
        'Moodle vs CRM',
        e,
        bajada:
            'Horas registradas en cada fuente, sin tope. Libres y Dictado solo existen en CRM.',
      ),
      pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1),
        },
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _linea),
          bottom: pw.BorderSide(color: _linea),
        ),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _tinta, width: 0.8),
              ),
            ),
            children: [
              enc('CATEGORÍA', derecha: false),
              enc('MOODLE (LMS)'),
              enc('CRM'),
              enc('DIFERENCIA'),
            ],
          ),
          for (final tipo in TipoCurso.values)
            pw.TableRow(
              children: [
                nombre(tipo.label),
                celda(
                  comparables.contains(tipo) ? _h(c.moodle[tipo] ?? 0) : '-',
                  color: comparables.contains(tipo) ? null : _tintaSuave,
                ),
                celda(_h(c.crm[tipo] ?? 0)),
                celda(
                  comparables.contains(tipo)
                      ? _diferencia((c.crm[tipo] ?? 0) - (c.moodle[tipo] ?? 0))
                      : '-',
                  color: _tintaSuave,
                ),
              ],
            ),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _fondoSuave),
            children: [
              nombre('Total', bold: true),
              celda(_h(moodle), bold: true),
              celda(_h(crmTotal), bold: true),
              celda(''),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: _marcaFondo,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(textoDiferencia, style: const pw.TextStyle(fontSize: 8)),
      ),
    ],
  );
}

String _diferencia(double valor) {
  if (valor.abs() < 0.05) return '0.0 h';
  return '${valor > 0 ? '+' : '-'}${valor.abs().toStringAsFixed(1)} h';
}

pw.Widget _evolucion(ReporteFormacion r, _EstiloReporte e) {
  final maximo = r.evolucion.fold<double>(
    0,
    (m, punto) => punto.horas > m ? punto.horas : m,
  );
  const alto = 70.0;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _titulo(
        'Evolución mensual',
        e,
        bajada: 'Horas válidas promedio por colaborador en los últimos meses',
      ),
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: pw.BoxDecoration(
          color: _fondoSuave,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _linea),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final (i, punto) in r.evolucion.indexed)
              pw.Expanded(
                child: pw.Column(
                  children: [
                    pw.Text(
                      _h(punto.horas),
                      style: pw.TextStyle(font: e.bold, fontSize: 8),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Container(
                      width: 36,
                      height: maximo == 0
                          ? 1
                          : (alto * punto.horas / maximo).clamp(1.0, alto),
                      decoration: pw.BoxDecoration(
                        // El último mes es el del período elegido.
                        color: i == r.evolucion.length - 1 ? _marca : _pista,
                        borderRadius: const pw.BorderRadius.vertical(
                          top: pw.Radius.circular(3),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${nombreMes(punto.mes.month)} ${punto.mes.year}',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: _tintaSuave,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

List<pw.Widget> _desglose(ReporteFormacion r, _EstiloReporte e) {
  final filas = [...r.desglose]
    ..sort((a, b) => a.porcentaje.compareTo(b.porcentaje));
  return [
    _titulo(
      r.desgloseTitulo ?? 'Desglose',
      e,
      bajada: 'Ordenado de menor a mayor cumplimiento',
    ),
    _tabla(
      e,
      anchos: const [3, 1.1, 1.8, 1.3, 1.2],
      derecha: const {1, 2, 3},
      encabezados: const [
        'NOMBRE',
        'INTEGRANTES',
        'HORAS / OBJETIVO',
        'CUMPLIMIENTO',
        'ESTADO',
      ],
      filas: [
        for (final f in filas)
          [
            pw.Text(f.nombre, style: pw.TextStyle(font: e.medio, fontSize: 8)),
            pw.Text('${f.integrantes}', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(
              '${_h(f.horas)} / ${_h0(f.objetivo)}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              formatearPorcentaje(f.porcentaje),
              style: pw.TextStyle(
                font: e.bold,
                fontSize: 8,
                color: _colorNivel[f.nivel],
              ),
            ),
            _chipEstado(f.estado, f.nivel, e),
          ],
      ],
    ),
  ];
}

List<pw.Widget> _integrantes(ReporteFormacion r, _EstiloReporte e) {
  final ordenados = [...r.miembros]
    ..sort((a, b) {
      final porcentaje = a.porcentajeTotal.compareTo(b.porcentajeTotal);
      return porcentaje != 0
          ? porcentaje
          : a.empleado.nombreCompleto.compareTo(b.empleado.nombreCompleto);
    });
  final lista = r.soloCriticos
      ? ordenados
            .where(
              (m) =>
                  NivelReporte.desdePorcentaje(m.porcentajeTotal) ==
                  NivelReporte.critico,
            )
            .toList()
      : ordenados;

  final titulo = r.soloCriticos
      ? _titulo(
          'Colaboradores que requieren seguimiento',
          e,
          bajada:
              '${lista.length} con menos de 70% de cumplimiento, de menor a mayor. '
              'Por categoría: horas válidas / objetivo.',
        )
      : _titulo(
          'Integrantes (${lista.length})',
          e,
          bajada:
              'De menor a mayor cumplimiento. Por categoría: horas válidas / objetivo.',
        );

  if (lista.isEmpty) {
    return [
      titulo,
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _fondoNivel[NivelReporte.ok],
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'Nadie está por debajo de 70% de cumplimiento en este período.',
          style: pw.TextStyle(
            font: e.medio,
            fontSize: 8.5,
            color: _colorNivel[NivelReporte.ok],
          ),
        ),
      ),
    ];
  }

  String categoria(CumplimientoEmpleado m, TipoCurso tipo) {
    final requeridas = m.horasRequeridas[tipo] ?? 0;
    if (requeridas <= 0) return '-';
    return '${m.horasAplicablesAlObjetivo(tipo).toStringAsFixed(1)}/'
        '${requeridas.toStringAsFixed(0)}';
  }

  final conEquipo = r.mostrarEquipo || r.soloCriticos;
  const estiloCelda = pw.TextStyle(fontSize: 7.5);

  return [
    titulo,
    _tabla(
      e,
      anchos: [
        2.3,
        if (conEquipo) 1.5,
        1.4,
        for (final _ in TipoCurso.values) 1.05,
        1.3,
        0.8,
      ],
      derecha: {
        for (var i = 0; i < TipoCurso.values.length + 2; i++)
          i + (conEquipo ? 3 : 2),
      },
      encabezados: [
        'COLABORADOR',
        if (conEquipo) r.soloCriticos ? 'ÁREA / EQUIPO' : 'EQUIPO',
        'SENIORITY',
        for (final tipo in TipoCurso.values) _nombreCorto[tipo]!.toUpperCase(),
        'HORAS',
        '%',
      ],
      filas: [
        for (final m in lista)
          [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  m.empleado.nombreCompleto,
                  style: pw.TextStyle(font: e.medio, fontSize: 7.5),
                ),
                pw.Text(
                  'Legajo ${m.empleado.legajo}',
                  style: const pw.TextStyle(fontSize: 6.5, color: _tintaSuave),
                ),
              ],
            ),
            if (conEquipo)
              pw.Text(
                r.soloCriticos
                    ? [m.empleado.area, m.empleado.equipo]
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .join(' / ')
                    : (m.empleado.equipo.trim().isEmpty
                          ? 'Sin equipo'
                          : m.empleado.equipo.trim()),
                style: estiloCelda,
              ),
            pw.Text(m.empleado.seniority.label, style: estiloCelda),
            for (final tipo in TipoCurso.values)
              pw.Text(categoria(m, tipo), style: estiloCelda),
            pw.Text(
              '${m.totalHorasCompletadas.toStringAsFixed(1)} / '
              '${m.totalHorasRequeridas.toStringAsFixed(0)}',
              style: estiloCelda,
            ),
            pw.Text(
              formatearPorcentaje(m.porcentajeTotal),
              style: pw.TextStyle(
                font: e.bold,
                fontSize: 7.5,
                color:
                    _colorNivel[NivelReporte.desdePorcentaje(
                      m.porcentajeTotal,
                    )],
              ),
            ),
          ],
      ],
    ),
  ];
}

/// Tabla con encabezado repetido en cada página y filas alternadas.
pw.Widget _tabla(
  _EstiloReporte e, {
  required List<double> anchos,
  required Set<int> derecha,
  required List<String> encabezados,
  required List<List<pw.Widget>> filas,
}) {
  pw.Widget alinear(int columna, pw.Widget hijo) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 4.5, horizontal: 5),
    alignment: derecha.contains(columna)
        ? pw.Alignment.centerRight
        : pw.Alignment.centerLeft,
    child: hijo,
  );

  return pw.Table(
    columnWidths: {
      for (final (i, ancho) in anchos.indexed) i: pw.FlexColumnWidth(ancho),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    tableWidth: pw.TableWidth.max,
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _linea, width: 0.6),
      bottom: pw.BorderSide(color: _linea, width: 0.6),
    ),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _tinta, width: 0.8)),
        ),
        children: [
          for (final (i, texto) in encabezados.indexed)
            alinear(
              i,
              pw.Text(
                texto,
                style: pw.TextStyle(
                  font: e.bold,
                  fontSize: 6.5,
                  letterSpacing: 0.3,
                  color: _tintaSuave,
                ),
              ),
            ),
        ],
      ),
      for (final (n, fila) in filas.indexed)
        pw.TableRow(
          decoration: n.isOdd
              ? const pw.BoxDecoration(color: _fondoSuave)
              : null,
          children: [for (final (i, celda) in fila.indexed) alinear(i, celda)],
        ),
    ],
  );
}

pw.Widget _notas() => pw.Container(
  padding: const pw.EdgeInsets.all(8),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: _linea),
    borderRadius: pw.BorderRadius.circular(4),
  ),
  child: pw.Text(
    'Cómo leer este reporte. Horas válidas: las que suman a la meta. '
    'Negocio y Blandas se acreditan con los cursos finalizados en Moodle; '
    'Libres y Dictado, con lo declarado en CRM. Cada persona suma como máximo '
    'su objetivo en cada categoría, según su seniority. El semáforo usa los '
    'cortes 100% (cumple) y 70% (atención).',
    style: const pw.TextStyle(fontSize: 7, color: _tintaSuave, lineSpacing: 2),
  ),
);
