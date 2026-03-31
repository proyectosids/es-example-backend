class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tenantCode,
    required this.userEmail,
    this.userName,
    this.userId,
    this.tenantId,
  });

  final String accessToken;
  final String refreshToken;
  final String tenantCode;
  final String userEmail;
  final String? userName;
  final String? userId;
  final String? tenantId;

  factory AuthSession.fromLoginResponse(Map<String, dynamic> json) {
    final user = (json['user'] is Map<String, dynamic>)
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AuthSession(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      tenantCode: (user['tenantCode'] ?? '').toString(),
      userEmail: (user['email'] ?? '').toString(),
      userName: (user['displayName'] ?? '').toString(),
      userId: (user['userId'] ?? '').toString(),
      tenantId: (user['tenantId'] ?? '').toString(),
    );
  }

  factory AuthSession.fromStorage(Map<String, String?> map) {
    return AuthSession(
      accessToken: (map['accessToken'] ?? '').toString(),
      refreshToken: (map['refreshToken'] ?? '').toString(),
      tenantCode: (map['tenantCode'] ?? '').toString(),
      userEmail: (map['userEmail'] ?? '').toString(),
      userName: (map['userName'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      tenantId: (map['tenantId'] ?? '').toString(),
    );
  }

  bool get isValid =>
      accessToken.trim().isNotEmpty &&
      refreshToken.trim().isNotEmpty &&
      tenantCode.trim().isNotEmpty &&
      userEmail.trim().isNotEmpty;

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? tenantCode,
    String? userEmail,
    String? userName,
    String? userId,
    String? tenantId,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tenantCode: tenantCode ?? this.tenantCode,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
    );
  }
}

class MeProfile {
  const MeProfile({
    required this.user,
    required this.memberships,
    required this.roleAssignments,
  });

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> memberships;
  final List<Map<String, dynamic>> roleAssignments;

  factory MeProfile.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(json['user'] as Map)
        : <String, dynamic>{};
    final memberships = (json['memberships'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    final roleAssignments =
        (json['roleAssignments'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);

    return MeProfile(
      user: user,
      memberships: memberships,
      roleAssignments: roleAssignments,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': user,
      'memberships': memberships,
      'roleAssignments': roleAssignments,
    };
  }
}

class AccessContext {
  const AccessContext({
    required this.permissions,
    required this.screens,
    this.orgUnitId,
  });

  final List<String> permissions;
  final List<String> screens;
  final String? orgUnitId;

  factory AccessContext.empty({String? orgUnitId}) {
    return AccessContext(
      permissions: const <String>[],
      screens: const <String>[],
      orgUnitId: orgUnitId,
    );
  }

  factory AccessContext.fromJson(Map<String, dynamic> json) {
    final permissions = (json['permissions'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    final screens = (json['screens'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    final orgUnitId = (json['orgUnitId'] ?? '').toString().trim();

    return AccessContext(
      permissions: permissions,
      screens: screens,
      orgUnitId: orgUnitId.isEmpty ? null : orgUnitId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'permissions': permissions,
      'screens': screens,
      'orgUnitId': orgUnitId,
    };
  }
}

enum SessionStatus { loading, guest, authenticated }

class SessionState {
  const SessionState({
    required this.status,
    this.session,
    this.profile,
    this.accessContext,
    this.errorMessage,
  });

  final SessionStatus status;
  final AuthSession? session;
  final MeProfile? profile;
  final AccessContext? accessContext;
  final String? errorMessage;

  factory SessionState.loading() =>
      const SessionState(status: SessionStatus.loading);

  factory SessionState.guest({String? errorMessage}) =>
      SessionState(status: SessionStatus.guest, errorMessage: errorMessage);

  factory SessionState.authenticated(
    AuthSession session, {
    MeProfile? profile,
    AccessContext? accessContext,
    String? errorMessage,
  }) => SessionState(
    status: SessionStatus.authenticated,
    session: session,
    profile: profile,
    accessContext: accessContext,
    errorMessage: errorMessage,
  );

  SessionState copyWith({
    SessionStatus? status,
    AuthSession? session,
    MeProfile? profile,
    AccessContext? accessContext,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SessionState(
      status: status ?? this.status,
      session: session ?? this.session,
      profile: profile ?? this.profile,
      accessContext: accessContext ?? this.accessContext,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get isAuthenticated =>
      status == SessionStatus.authenticated && session != null;
}
