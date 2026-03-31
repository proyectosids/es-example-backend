import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_repository.dart';
import '../../../auth/presentation/access/access_control.dart';
import '../../../auth/presentation/providers/session_provider.dart';
import '../providers/admin_providers.dart';

class AdminOrgStructureScreen extends ConsumerStatefulWidget {
  const AdminOrgStructureScreen({super.key});

  @override
  ConsumerState<AdminOrgStructureScreen> createState() =>
      _AdminOrgStructureScreenState();
}

class _AdminOrgStructureScreenState
    extends ConsumerState<AdminOrgStructureScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final scopeId = session.accessContext?.orgUnitId;
    final orgAsync = ref.watch(adminOrgUnitsProvider((orgUnitId: scopeId)));
    final canManageOrg = ref.watch(
      hasPermissionProvider(AppPermission.orgManage),
    );
    final repo = ref.watch(adminRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Estructura')),
      body: orgAsync.when(
        data: (units) {
          if ((scopeId ?? '').isEmpty) {
            return const _EmptyState(
              message: 'Selecciona un org scope para consultar estructura.',
            );
          }
          if (units.isEmpty) {
            return const _EmptyState(
              message: 'No hay unidades organizacionales visibles.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: units.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = units[index];
              final name = (row['Name'] ?? row['name'] ?? '').toString();
              final code = (row['Code'] ?? row['code'] ?? '').toString();
              final type =
                  (row['OrgUnitTypeCode'] ?? row['orgUnitTypeCode'] ?? '')
                      .toString();
              final id = (row['OrgUnitId'] ?? row['orgUnitId'] ?? '')
                  .toString();
              final path = (row['Path'] ?? row['path'] ?? '').toString();
              final isActiveRaw = row['IsActive'] ?? row['isActive'];
              final isActive = isActiveRaw == true || isActiveRaw == 1;

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.account_tree_outlined),
                  title: Text(name.isEmpty ? '(sin nombre)' : name),
                  subtitle: Text(
                    '${type.isEmpty ? 'TYPE' : type} · $code\n$id',
                  ),
                  isThreeLine: true,
                  trailing: canManageOrg
                      ? IconButton(
                          tooltip: 'Editar unidad',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            if (id.isEmpty) return;
                            await _openEditDialog(
                              context,
                              repo: repo,
                              scopeId: scopeId,
                              orgUnitId: id,
                              initialName: name,
                              initialPath: path,
                              initialActive: isActive,
                            );
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _EmptyState(message: repo.readableError(e)),
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context, {
    required AdminRepository repo,
    required String? scopeId,
    required String orgUnitId,
    required String initialName,
    required String initialPath,
    required bool initialActive,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final pathCtrl = TextEditingController(text: initialPath);
    bool isActive = initialActive;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Editar unidad organizacional'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: pathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Path (opcional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activo'),
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(ctx);
                    try {
                      await repo.updateOrgUnit(
                        orgUnitId: orgUnitId,
                        name: nameCtrl.text.trim(),
                        path: pathCtrl.text.trim(),
                        isActive: isActive,
                      );
                      if (!mounted) return;
                      ref.invalidate(
                        adminOrgUnitsProvider((orgUnitId: scopeId)),
                      );
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Unidad actualizada.')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(repo.readableError(e))),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    pathCtrl.dispose();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
