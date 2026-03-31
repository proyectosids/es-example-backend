import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../admin/presentation/screens/admin_menu_screen.dart';
import '../../data/models/auth_session.dart';
import '../providers/session_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController(text: 'ulv-demo');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _tenantController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionControllerProvider);
    final isAuth = sessionState.isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isAuth
            ? _buildAuthenticated(sessionState)
            : _buildLogin(sessionState),
      ),
    );
  }

  Widget _buildAuthenticated(SessionState sessionState) {
    final session = sessionState.session!;
    final access = sessionState.accessContext;
    final adminScreens = ref.watch(adminAvailableScreensProvider);
    final permissionCodes = access?.permissions ?? const <String>[];
    final screenKeys = access?.screens ?? const <String>[];
    final memberships = sessionState.profile?.memberships ?? const [];

    final scopeItems = memberships
        .map((m) {
          final id = (m['OrgUnitId'] ?? m['orgUnitId'] ?? '').toString().trim();
          if (id.isEmpty) return null;
          final name = (m['OrgUnitName'] ?? m['orgUnitName'] ?? 'Org Unit')
              .toString()
              .trim();
          final type = (m['OrgUnitTypeCode'] ?? m['orgUnitTypeCode'] ?? '')
              .toString();
          final isPrimary =
              m['IsPrimary'] == true ||
              m['isPrimary'] == true ||
              m['IsPrimary'] == 1 ||
              m['isPrimary'] == 1;
          return _OrgScopeItem(
            id: id,
            label: type.isEmpty ? name : '$name ($type)',
            isPrimary: isPrimary,
          );
        })
        .whereType<_OrgScopeItem>()
        .toList(growable: false);

    final selectedScopeId = access?.orgUnitId;
    String? selectedScopeLabel;
    for (final item in scopeItems) {
      if (item.id == selectedScopeId) {
        selectedScopeLabel = item.label;
        break;
      }
    }

    return ListView(
      children: [
        Text(
          session.userName?.trim().isNotEmpty == true
              ? session.userName!.trim()
              : session.userEmail,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text('Tenant: ${session.tenantCode}'),
        Text('Email: ${session.userEmail}'),
        if (access != null) ...[
          const SizedBox(height: 8),
          Text(
            'Org scope: ${access.orgUnitId ?? '(global)'}'
            '${(selectedScopeLabel ?? '').trim().isNotEmpty ? ' / $selectedScopeLabel' : ''}',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.verified_user_outlined,
                label: 'Permisos',
                value: access.permissions.length.toString(),
              ),
              _StatChip(
                icon: Icons.mobile_screen_share_outlined,
                label: 'Pantallas',
                value: access.screens.length.toString(),
              ),
            ],
          ),
        ],
        if (scopeItems.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Alcance activo',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: scopeItems.any((i) => i.id == selectedScopeId)
                ? selectedScopeId
                : scopeItems.first.id,
            selectedItemBuilder: (context) {
              return scopeItems
                  .map(
                    (item) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.isPrimary
                            ? '${item.label} - primaria'
                            : item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  )
                  .toList();
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              for (final item in scopeItems)
                DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(
                    item.isPrimary ? '${item.label} - primaria' : item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
            ],
            onChanged: (value) async {
              if (value == null || value.trim().isEmpty) return;
              await ref
                  .read(sessionControllerProvider.notifier)
                  .selectOrgUnitScope(value);
            },
          ),
        ],
        if (permissionCodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CompactExpansionCard(
            icon: Icons.verified_user_outlined,
            title: 'Permisos activos',
            count: permissionCodes.length,
            children: [
              for (final code in permissionCodes)
                _CompactInfoItem(title: _permissionLabel(code), subtitle: code),
            ],
          ),
        ],
        if (screenKeys.isNotEmpty) ...[
          const SizedBox(height: 8),
          _CompactExpansionCard(
            icon: Icons.mobile_screen_share_outlined,
            title: 'Pantallas habilitadas',
            count: screenKeys.length,
            children: [
              for (final key in screenKeys)
                _CompactInfoItem(title: _screenLabel(key), subtitle: key),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (adminScreens.isNotEmpty) ...[
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AdminMenuScreen(),
                ),
              );
            },
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text('Panel administrativo (${adminScreens.length})'),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.tonalIcon(
          onPressed: () async {
            await ref
                .read(sessionControllerProvider.notifier)
                .reloadAccessContext(
                  orgUnitId: sessionState.accessContext?.orgUnitId,
                );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contexto actualizado.')),
            );
          },
          icon: const Icon(Icons.sync),
          label: const Text('Actualizar contexto'),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () async {
            await ref.read(sessionControllerProvider.notifier).logout();
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Sesion cerrada.')));
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesion'),
        ),
      ],
    );
  }

  String _permissionLabel(String code) {
    const labels = <String, String>{
      'app.catalog.read': 'Leer catalogo de estudio',
      'app.study_marks.write': 'Registrar dias estudiados',
      'app.group.members.read': 'Ver miembros del grupo pequeno',
      'app.group.members.manage': 'Gestionar miembros del grupo pequeno',
      'app.reports.scope.read': 'Ver reportes por alcance',
      'app.reports.scope.export': 'Exportar reportes',
      'app.users.read': 'Ver usuarios',
      'app.users.manage': 'Gestionar usuarios',
      'app.roles.assign': 'Asignar roles',
      'app.org.manage': 'Gestionar estructura organizacional',
      'app.sync.execute': 'Ejecutar sincronizacion de datos',
    };
    return labels[code] ?? 'Permiso no catalogado';
  }

  String _screenLabel(String key) {
    const labels = <String, String>{
      'mobile.quarterlies': 'Trimestres',
      'mobile.lessons': 'Lecciones del trimestre',
      'mobile.lesson_reader': 'Lector diario',
      'mobile.study_progress': 'Progreso personal',
      'admin.users': 'Administracion de usuarios',
      'admin.roles': 'Administracion de roles',
      'admin.org_structure': 'Estructura organizacional',
      'admin.reports': 'Reportes',
    };
    return labels[key] ?? 'Pantalla no catalogada';
  }

  Widget _buildLogin(SessionState sessionState) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: _tenantController,
            decoration: const InputDecoration(labelText: 'Tenant code'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: (v) => (v ?? '').isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 18),
          if ((sessionState.errorMessage ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                sessionState.errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          FilledButton.icon(
            onPressed: _submitting
                ? null
                : () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _submitting = true);
                    final ok = await ref
                        .read(sessionControllerProvider.notifier)
                        .login(
                          tenantCode: _tenantController.text,
                          email: _emailController.text,
                          password: _passwordController.text,
                        );
                    if (!mounted) return;
                    setState(() => _submitting = false);
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sesion iniciada.')),
                      );
                      Navigator.of(context).pop();
                    }
                  },
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: const Text('Iniciar sesion'),
          ),
        ],
      ),
    );
  }
}

class _OrgScopeItem {
  const _OrgScopeItem({
    required this.id,
    required this.label,
    required this.isPrimary,
  });

  final String id;
  final String label;
  final bool isPrimary;
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CompactExpansionCard extends StatelessWidget {
  const _CompactExpansionCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.children,
  });

  final IconData icon;
  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0x14000000),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        collapsedIconColor: Colors.white70,
        iconColor: Colors.white,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        leading: Icon(icon, size: 18, color: Colors.white),
        title: Text(
          '$title ($count)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        children: children,
      ),
    );
  }
}

class _CompactInfoItem extends StatelessWidget {
  const _CompactInfoItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}
