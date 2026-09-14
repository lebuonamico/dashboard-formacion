import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/side_menu.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

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
          subtitle: const Text('Subí planillas con las listas de empleados, cursos y cursadas'),
          trailing: OutlinedButton.icon(
            onPressed: () {},
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
                initialValue: 'Q3',
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
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: '8',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Carga Base Requerida (Horas)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  suffixText: 'hs',
                ),
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
          value: true,
          activeColor: const Color(0xFF0D53C3),
          onChanged: (_) {},
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh, color: Color(0xFFDC2626)),
              label: const Text('Restablecer Datos Mock', style: TextStyle(color: Color(0xFFDC2626))),
            ),
          ],
        ),
      ],
    );
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