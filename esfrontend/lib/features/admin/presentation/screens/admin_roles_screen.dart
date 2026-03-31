import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/session_provider.dart';
import '../providers/admin_providers.dart';

class AdminRolesScreen extends ConsumerWidget {
  const AdminRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(adminRolesProvider);
    final session = ref.watch(sessionControllerProvider);
    final repo = ref.watch(adminRepositoryProvider);

    final currentAssignments = session.profile?.roleAssignments ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Roles')),
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
                    'Roles asignados a tu usuario',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (currentAssignments.isEmpty)
                    const Text('Sin asignaciones visibles.'),
                  for (final role in currentAssignments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${(role['RoleName'] ?? role['roleName'] ?? '').toString()} '
                        '(${(role['RoleCode'] ?? role['roleCode'] ?? '').toString()})',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Catalogo de roles del sistema',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          rolesAsync.when(
            data: (roles) {
              if (roles.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('No hay roles disponibles.'),
                );
              }
              return Column(
                children: [
                  for (final role in roles)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.security_outlined),
                        title: Text(
                          (role['Name'] ?? role['name'] ?? '').toString(),
                        ),
                        subtitle: Text(
                          '${(role['Code'] ?? role['code'] ?? '').toString()}\n'
                          '${(role['Description'] ?? role['description'] ?? '').toString()}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(repo.readableError(e)),
            ),
          ),
        ],
      ),
    );
  }
}
