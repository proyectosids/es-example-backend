import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_repository.dart';
import '../../../auth/presentation/access/access_control.dart';
import '../../../auth/presentation/providers/session_provider.dart';
import '../providers/admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final scopeId = session.accessContext?.orgUnitId;
    final usersAsync = ref.watch(adminUsersProvider((orgUnitId: scopeId)));
    final rolesAsync = ref.watch(adminRolesProvider);
    final orgUnitsAsync = ref.watch(
      adminOrgUnitsProvider((orgUnitId: scopeId)),
    );

    final canManageUsers = ref.watch(
      hasPermissionProvider(AppPermission.usersManage),
    );
    final canAssignRoles = ref.watch(
      hasPermissionProvider(AppPermission.rolesAssign),
    );

    final repo = ref.watch(adminRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin · Usuarios')),
      floatingActionButton: canManageUsers
          ? FloatingActionButton.extended(
              onPressed: _creating
                  ? null
                  : () async {
                      final roles = rolesAsync.valueOrNull ?? const [];
                      final orgUnits = orgUnitsAsync.valueOrNull ?? const [];
                      await _openCreateUserDialog(
                        context,
                        repo: repo,
                        scopeId: scopeId,
                        roles: roles,
                        orgUnits: orgUnits,
                      );
                    },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Crear usuario'),
            )
          : null,
      body: usersAsync.when(
        data: (items) {
          if ((scopeId ?? '').isEmpty) {
            return const _EmptyState(
              message: 'Selecciona un org scope para consultar usuarios.',
            );
          }
          if (items.isEmpty) {
            return const _EmptyState(
              message: 'No hay usuarios visibles en este alcance.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = items[index];
              final userId = (row['UserId'] ?? row['userId'] ?? '').toString();
              final name = (row['DisplayName'] ?? row['displayName'] ?? '')
                  .toString();
              final email = (row['Email'] ?? row['email'] ?? '').toString();
              final orgName = (row['OrgUnitName'] ?? row['orgUnitName'] ?? '')
                  .toString();
              final type =
                  (row['OrgUnitTypeCode'] ?? row['orgUnitTypeCode'] ?? '')
                      .toString();

              return Card(
                child: ListTile(
                  title: Text(name.isEmpty ? email : name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email),
                      if (orgName.isNotEmpty)
                        Text(type.isEmpty ? orgName : '$orgName ($type)'),
                    ],
                  ),
                  leading: const Icon(Icons.person_outline_rounded),
                  trailing: canAssignRoles
                      ? IconButton(
                          tooltip: 'Asignar rol',
                          icon: const Icon(Icons.security_outlined),
                          onPressed: () async {
                            if (userId.isEmpty) return;
                            final roles = rolesAsync.valueOrNull ?? const [];
                            final orgUnits =
                                orgUnitsAsync.valueOrNull ?? const [];
                            await _openAssignRoleDialog(
                              context,
                              repo: repo,
                              userId: userId,
                              fallbackScopeId: scopeId,
                              roles: roles,
                              orgUnits: orgUnits,
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

  Future<void> _openCreateUserDialog(
    BuildContext context, {
    required AdminRepository repo,
    required String? scopeId,
    required List<Map<String, dynamic>> roles,
    required List<Map<String, dynamic>> orgUnits,
  }) async {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();

    var selectedMembershipType = 'MEMBER';
    String? selectedMembershipOrgId = (scopeId ?? '').trim().isNotEmpty
        ? scopeId
        : null;
    String selectedRoleCode = '__none__';
    String? selectedRoleScopeId = (scopeId ?? '').trim().isNotEmpty
        ? scopeId
        : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Crear usuario'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Requerido' : null,
                        ),
                        TextFormField(
                          controller: passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Password temporal',
                          ),
                          validator: (v) =>
                              (v ?? '').trim().isEmpty ? 'Requerido' : null,
                        ),
                        TextFormField(
                          controller: firstNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                          ),
                        ),
                        TextFormField(
                          controller: lastNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Apellido',
                          ),
                        ),
                        TextFormField(
                          controller: displayNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedMembershipType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo membresia',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'MEMBER',
                              child: Text('MEMBER'),
                            ),
                            DropdownMenuItem(
                              value: 'LEADER',
                              child: Text('LEADER'),
                            ),
                            DropdownMenuItem(
                              value: 'PASTOR',
                              child: Text('PASTOR'),
                            ),
                            DropdownMenuItem(
                              value: 'DIRECTOR',
                              child: Text('DIRECTOR'),
                            ),
                          ],
                          onChanged: (v) => setDialogState(
                            () => selectedMembershipType = v ?? 'MEMBER',
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedMembershipOrgId,
                          decoration: const InputDecoration(
                            labelText: 'Org unidad membresia',
                          ),
                          items: [
                            for (final unit in orgUnits)
                              DropdownMenuItem(
                                value: (unit['OrgUnitId'] ?? unit['orgUnitId'])
                                    .toString(),
                                child: Text(
                                  '${(unit['Name'] ?? unit['name'] ?? '').toString()} '
                                  '(${(unit['OrgUnitTypeCode'] ?? unit['orgUnitTypeCode'] ?? '').toString()})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => selectedMembershipOrgId = v),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedRoleCode,
                          decoration: const InputDecoration(
                            labelText: 'Rol inicial (opcional)',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '__none__',
                              child: Text('Sin rol inicial'),
                            ),
                            for (final role in roles)
                              DropdownMenuItem(
                                value: (role['Code'] ?? role['code'])
                                    .toString(),
                                child: Text(
                                  (role['Name'] ?? role['name']).toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setDialogState(
                            () => selectedRoleCode = v ?? '__none__',
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedRoleScopeId,
                          decoration: const InputDecoration(
                            labelText: 'Scope del rol (si aplica)',
                          ),
                          items: [
                            for (final unit in orgUnits)
                              DropdownMenuItem(
                                value: (unit['OrgUnitId'] ?? unit['orgUnitId'])
                                    .toString(),
                                child: Text(
                                  (unit['Name'] ?? unit['name']).toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => selectedRoleScopeId = v),
                        ),
                      ],
                    ),
                  ),
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
                    if (!formKey.currentState!.validate()) return;
                    if ((selectedMembershipOrgId ?? '').trim().isEmpty) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Selecciona org de membresia.'),
                        ),
                      );
                      return;
                    }

                    setState(() => _creating = true);
                    try {
                      await repo.createUser(
                        email: emailCtrl.text.trim(),
                        password: passwordCtrl.text.trim(),
                        firstName: firstNameCtrl.text.trim(),
                        lastName: lastNameCtrl.text.trim(),
                        displayName: displayNameCtrl.text.trim(),
                        membershipOrgUnitId: selectedMembershipOrgId,
                        membershipType: selectedMembershipType,
                        roleCode: selectedRoleCode == '__none__'
                            ? null
                            : selectedRoleCode,
                        scopeOrgUnitId: selectedRoleScopeId,
                      );
                      if (!mounted) return;
                      ref.invalidate(adminUsersProvider((orgUnitId: scopeId)));
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Usuario creado.')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(repo.readableError(e))),
                      );
                    } finally {
                      if (mounted) setState(() => _creating = false);
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    emailCtrl.dispose();
    passwordCtrl.dispose();
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    displayNameCtrl.dispose();
  }

  Future<void> _openAssignRoleDialog(
    BuildContext context, {
    required AdminRepository repo,
    required String userId,
    required String? fallbackScopeId,
    required List<Map<String, dynamic>> roles,
    required List<Map<String, dynamic>> orgUnits,
  }) async {
    final formKey = GlobalKey<FormState>();
    String? selectedRoleCode;
    String? selectedScopeId = (fallbackScopeId ?? '').trim().isNotEmpty
        ? fallbackScopeId
        : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Asignar rol'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedRoleCode,
                        decoration: const InputDecoration(labelText: 'Rol'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Requerido' : null,
                        items: [
                          for (final role in roles)
                            DropdownMenuItem(
                              value: (role['Code'] ?? role['code']).toString(),
                              child: Text(
                                '${(role['Name'] ?? role['name']).toString()} '
                                '(${(role['Code'] ?? role['code']).toString()})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => selectedRoleCode = v),
                      ),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedScopeId,
                        decoration: const InputDecoration(
                          labelText: 'Scope org unit',
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Requerido' : null,
                        items: [
                          for (final unit in orgUnits)
                            DropdownMenuItem(
                              value: (unit['OrgUnitId'] ?? unit['orgUnitId'])
                                  .toString(),
                              child: Text(
                                (unit['Name'] ?? unit['name']).toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => selectedScopeId = v),
                      ),
                    ],
                  ),
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
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await repo.assignRole(
                        userId: userId,
                        roleCode: selectedRoleCode!,
                        scopeOrgUnitId: selectedScopeId!,
                      );
                      if (!mounted) return;
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Rol asignado.')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(repo.readableError(e))),
                      );
                    }
                  },
                  child: const Text('Asignar'),
                ),
              ],
            );
          },
        );
      },
    );
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
