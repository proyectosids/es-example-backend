import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/access/access_control.dart';
import '../providers/admin_providers.dart';
import 'admin_org_structure_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_roles_screen.dart';
import 'admin_users_screen.dart';

class AdminMenuScreen extends ConsumerWidget {
  const AdminMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(adminAvailableScreensProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Panel administrativo')),
      body: available.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tu cuenta no tiene pantallas administrativas habilitadas.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: available.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = available[index];
                return Card(
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.description),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      switch (item.key) {
                        case AppScreenKey.adminUsers:
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminUsersScreen(),
                            ),
                          );
                          break;
                        case AppScreenKey.adminRoles:
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminRolesScreen(),
                            ),
                          );
                          break;
                        case AppScreenKey.adminOrgStructure:
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminOrgStructureScreen(),
                            ),
                          );
                          break;
                        case AppScreenKey.adminReports:
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminReportsScreen(),
                            ),
                          );
                          break;
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
