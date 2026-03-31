import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/auth_session.dart';
import '../providers/session_provider.dart';

class AppPermission {
  static const catalogRead = 'app.catalog.read';
  static const studyMarksWrite = 'app.study_marks.write';
  static const syncExecute = 'app.sync.execute';
  static const usersRead = 'app.users.read';
  static const usersManage = 'app.users.manage';
  static const rolesAssign = 'app.roles.assign';
  static const orgManage = 'app.org.manage';
}

class AppScreenKey {
  static const mobileQuarterlies = 'mobile.quarterlies';
  static const mobileLessons = 'mobile.lessons';
  static const mobileLessonReader = 'mobile.lesson_reader';
  static const mobileStudyProgress = 'mobile.study_progress';
  static const adminUsers = 'admin.users';
  static const adminRoles = 'admin.roles';
  static const adminOrgStructure = 'admin.org_structure';
  static const adminReports = 'admin.reports';
}

final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  final state = ref.watch(sessionControllerProvider);
  return _hasPermission(state, permission);
});

final canOpenScreenProvider = Provider.family<bool, String>((ref, screenKey) {
  final state = ref.watch(sessionControllerProvider);
  return _canOpenScreen(state, screenKey);
});

bool _hasPermission(SessionState state, String permission) {
  if (!state.isAuthenticated) {
    return permission == AppPermission.catalogRead ||
        permission == AppPermission.studyMarksWrite;
  }

  final access = state.accessContext;
  if (access == null) {
    return true;
  }

  return access.permissions.contains(permission);
}

bool _canOpenScreen(SessionState state, String screenKey) {
  if (!state.isAuthenticated) {
    return screenKey == AppScreenKey.mobileQuarterlies ||
        screenKey == AppScreenKey.mobileLessons ||
        screenKey == AppScreenKey.mobileLessonReader ||
        screenKey == AppScreenKey.mobileStudyProgress;
  }

  final access = state.accessContext;
  if (access == null) {
    return true;
  }

  return access.screens.contains(screenKey);
}
