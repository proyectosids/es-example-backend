import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/access/access_control.dart';
import '../../../auth/presentation/providers/session_provider.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../data/repositories/admin_repository.dart';

typedef ScopeQuery = ({String? orgUnitId});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});

final adminAvailableScreensProvider = Provider<List<AdminScreenDef>>((ref) {
  final state = ref.watch(sessionControllerProvider);
  final screens = state.accessContext?.screens ?? const <String>[];
  final defs = _adminDefinitions.where((d) => screens.contains(d.key)).toList();
  return defs;
});

final adminUsersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ScopeQuery>((
      ref,
      query,
    ) async {
      final scopeId = (query.orgUnitId ?? '').trim();
      if (scopeId.isEmpty) return const <Map<String, dynamic>>[];
      final repo = ref.watch(adminRepositoryProvider);
      return repo.listUsersByScope(orgUnitId: scopeId);
    });

final adminRolesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.listRoles();
});

final adminOrgUnitsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, ScopeQuery>((
      ref,
      query,
    ) async {
      final scopeId = (query.orgUnitId ?? '').trim();
      if (scopeId.isEmpty) return const <Map<String, dynamic>>[];
      final repo = ref.watch(adminRepositoryProvider);
      return repo.listOrgUnits(orgUnitId: scopeId);
    });

final adminReportsSummaryProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(sessionControllerProvider);
  final access = state.accessContext;
  final profile = state.profile;
  return <String, dynamic>{
    'orgUnitId': access?.orgUnitId,
    'permissions': access?.permissions ?? const <String>[],
    'screens': access?.screens ?? const <String>[],
    'membershipsCount': profile?.memberships.length ?? 0,
    'rolesCount': profile?.roleAssignments.length ?? 0,
  };
});

class AdminScreenDef {
  const AdminScreenDef({
    required this.key,
    required this.title,
    required this.description,
  });

  final String key;
  final String title;
  final String description;
}

const _adminDefinitions = <AdminScreenDef>[
  AdminScreenDef(
    key: AppScreenKey.adminUsers,
    title: 'Usuarios',
    description: 'Gestion y consulta de usuarios por alcance.',
  ),
  AdminScreenDef(
    key: AppScreenKey.adminRoles,
    title: 'Roles',
    description: 'Consulta de roles del sistema y asignaciones.',
  ),
  AdminScreenDef(
    key: AppScreenKey.adminOrgStructure,
    title: 'Estructura',
    description: 'Consulta de unidades organizacionales.',
  ),
  AdminScreenDef(
    key: AppScreenKey.adminReports,
    title: 'Reportes',
    description: 'Resumen de permisos y pantallas por alcance.',
  ),
];
