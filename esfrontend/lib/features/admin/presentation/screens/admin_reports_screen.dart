import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminReportsSummaryProvider);
    final permissions = (summary['permissions'] as List<dynamic>? ?? const [])
        .cast<String>();
    final screens = (summary['screens'] as List<dynamic>? ?? const [])
        .cast<String>();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen de alcance',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text('Org scope: ${summary['orgUnitId'] ?? '(global)'}'),
                  Text('Permisos: ${permissions.length}'),
                  Text('Pantallas: ${screens.length}'),
                  Text('Memberships: ${summary['membershipsCount'] ?? 0}'),
                  Text('Roles asignados: ${summary['rolesCount'] ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permisos activos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (permissions.isEmpty)
                    const Text('Sin permisos disponibles.'),
                  for (final p in permissions) Text('• $p'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pantallas habilitadas',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (screens.isEmpty) const Text('Sin pantallas disponibles.'),
                  for (final s in screens) Text('• $s'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
