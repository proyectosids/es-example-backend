import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/auth_session.dart';
import '../../data/repositories/auth_repository.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  return AuthRepository(api);
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
      return SessionController(
        ref.read(tokenStorageProvider),
        ref.read(authRepositoryProvider),
      );
    });

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._tokenStorage, this._authRepository)
    : super(SessionState.loading());

  final TokenStorage _tokenStorage;
  final AuthRepository _authRepository;

  Completer<String?>? _refreshCompleter;

  Future<void> initialize() async {
    final raw = await _tokenStorage.readSession();
    final session = AuthSession.fromStorage(raw);
    if (session.isValid) {
      final cachedProfileJson = await _tokenStorage.readCachedProfile();
      final cachedAccessJson = await _tokenStorage.readCachedAccessContext();
      final cachedProfile = cachedProfileJson == null
          ? null
          : MeProfile.fromJson(cachedProfileJson);
      final cachedAccess = cachedAccessJson == null
          ? null
          : AccessContext.fromJson(cachedAccessJson);

      state = SessionState.authenticated(
        session,
        profile: cachedProfile,
        accessContext: cachedAccess,
      );
      final selectedOrgUnitId =
          (raw['selectedOrgUnitId'] ?? cachedAccess?.orgUnitId ?? '').trim();
      unawaited(
        _hydrateAccessContext(
          orgUnitId: selectedOrgUnitId.isEmpty ? null : selectedOrgUnitId,
        ),
      );
      return;
    }
    state = SessionState.guest();
  }

  Future<bool> login({
    required String tenantCode,
    required String email,
    required String password,
  }) async {
    state = SessionState.loading();
    try {
      final session = await _authRepository.login(
        tenantCode: tenantCode.trim(),
        email: email.trim(),
        password: password,
      );

      await _tokenStorage.writeSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        tenantCode: session.tenantCode,
        userEmail: session.userEmail,
        userName: session.userName,
        userId: session.userId,
        tenantId: session.tenantId,
      );

      state = SessionState.authenticated(session);
      unawaited(_hydrateAccessContext());
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? ((e.response?.data as Map<String, dynamic>)['message'] ??
                    'No fue posible iniciar sesion')
                .toString()
          : 'No fue posible iniciar sesion';
      state = SessionState.guest(errorMessage: msg);
      return false;
    } catch (e) {
      state = SessionState.guest(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.clearSession();
    state = SessionState.guest();
  }

  Future<String?> getAccessToken() async {
    final session = state.session;
    if (session == null || !state.isAuthenticated) return null;
    return session.accessToken;
  }

  Future<String?> refreshAccessToken() async {
    final session = state.session;
    if (session == null || session.refreshToken.isEmpty) {
      await logout();
      return null;
    }

    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final accessToken = await _authRepository.refresh(
        refreshToken: session.refreshToken,
      );
      final updated = session.copyWith(accessToken: accessToken);
      await _tokenStorage.writeAccessToken(accessToken);
      state = state.copyWith(session: updated, clearError: true);
      completer.complete(accessToken);
      unawaited(
        _hydrateAccessContext(orgUnitId: state.accessContext?.orgUnitId),
      );
      return accessToken;
    } on DioException catch (e) {
      if (_isInvalidRefresh(e)) {
        await logout();
      }
      completer.complete(null);
      return null;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> reloadAccessContext({String? orgUnitId}) async {
    if (!state.isAuthenticated) return;
    await _hydrateAccessContext(orgUnitId: orgUnitId);
  }

  Future<void> selectOrgUnitScope(String? orgUnitId) async {
    if (!state.isAuthenticated) return;
    if (orgUnitId == null || orgUnitId.trim().isEmpty) {
      await _tokenStorage.clearSelectedOrgUnitId();
      await _hydrateAccessContext();
      return;
    }
    await _tokenStorage.writeSelectedOrgUnitId(orgUnitId.trim());
    await _hydrateAccessContext(orgUnitId: orgUnitId.trim());
  }

  Future<void> _hydrateAccessContext({String? orgUnitId}) async {
    final current = state;
    final session = current.session;
    if (session == null) return;

    try {
      var accessToken = session.accessToken;
      final me = await _authRepository.fetchMe(accessToken: accessToken);
      final persistedOrgId = await _tokenStorage.readSelectedOrgUnitId();
      final fallbackOrg = _resolveDefaultOrgUnitId(me);
      var targetOrg = orgUnitId ?? persistedOrgId ?? fallbackOrg;
      final availableOrgIds = _membershipOrgUnitIds(me);
      if (targetOrg != null &&
          targetOrg.trim().isNotEmpty &&
          !availableOrgIds.contains(targetOrg)) {
        targetOrg = fallbackOrg;
      }
      final permissions = await _authRepository.fetchPermissions(
        accessToken: accessToken,
        orgUnitId: targetOrg,
      );
      final screens = await _authRepository.fetchScreens(
        accessToken: accessToken,
        orgUnitId: targetOrg,
      );

      state = SessionState.authenticated(
        session,
        profile: me,
        accessContext: AccessContext(
          permissions: permissions,
          screens: screens,
          orgUnitId: targetOrg,
        ),
      );
      await _tokenStorage.writeCachedProfile(me.toJson());
      await _tokenStorage.writeCachedAccessContext(
        AccessContext(
          permissions: permissions,
          screens: screens,
          orgUnitId: targetOrg,
        ).toJson(),
      );
      if (targetOrg != null && targetOrg.trim().isNotEmpty) {
        await _tokenStorage.writeSelectedOrgUnitId(targetOrg);
      } else {
        await _tokenStorage.clearSelectedOrgUnitId();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await refreshAccessToken();
        if (refreshed == null) return;
        final me = await _authRepository.fetchMe(accessToken: refreshed);
        final persistedOrgId = await _tokenStorage.readSelectedOrgUnitId();
        final fallbackOrg = _resolveDefaultOrgUnitId(me);
        var targetOrg = orgUnitId ?? persistedOrgId ?? fallbackOrg;
        final availableOrgIds = _membershipOrgUnitIds(me);
        if (targetOrg != null &&
            targetOrg.trim().isNotEmpty &&
            !availableOrgIds.contains(targetOrg)) {
          targetOrg = fallbackOrg;
        }
        final permissions = await _authRepository.fetchPermissions(
          accessToken: refreshed,
          orgUnitId: targetOrg,
        );
        final screens = await _authRepository.fetchScreens(
          accessToken: refreshed,
          orgUnitId: targetOrg,
        );
        state = SessionState.authenticated(
          state.session!,
          profile: me,
          accessContext: AccessContext(
            permissions: permissions,
            screens: screens,
            orgUnitId: targetOrg,
          ),
        );
        await _tokenStorage.writeCachedProfile(me.toJson());
        await _tokenStorage.writeCachedAccessContext(
          AccessContext(
            permissions: permissions,
            screens: screens,
            orgUnitId: targetOrg,
          ).toJson(),
        );
        if (targetOrg != null && targetOrg.trim().isNotEmpty) {
          await _tokenStorage.writeSelectedOrgUnitId(targetOrg);
        } else {
          await _tokenStorage.clearSelectedOrgUnitId();
        }
        return;
      }

      if (_isNetworkError(e)) {
        state = current.copyWith(
          errorMessage: 'Sin conexion: usando contexto local almacenado.',
        );
      } else {
        state = current.copyWith(
          errorMessage: 'Sesion activa, pero no se pudo refrescar contexto.',
        );
      }
    } catch (_) {
      state = current.copyWith(
        errorMessage: 'Sin conexion: usando contexto local almacenado.',
      );
    }
  }

  bool _isNetworkError(DioException e) {
    if (e.response != null) return false;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  bool _isInvalidRefresh(DioException e) {
    final code = e.response?.statusCode;
    return code == 401 || code == 403;
  }

  String? _resolveDefaultOrgUnitId(MeProfile profile) {
    for (final membership in profile.memberships) {
      final isPrimary =
          membership['IsPrimary'] == true ||
          membership['isPrimary'] == true ||
          membership['IsPrimary'] == 1 ||
          membership['isPrimary'] == 1;
      final id = (membership['OrgUnitId'] ?? membership['orgUnitId'] ?? '')
          .toString();
      if (isPrimary && id.trim().isNotEmpty) {
        return id;
      }
    }

    if (profile.memberships.isNotEmpty) {
      final first = profile.memberships.first;
      final id = (first['OrgUnitId'] ?? first['orgUnitId'] ?? '').toString();
      if (id.trim().isNotEmpty) return id;
    }

    return null;
  }

  Set<String> _membershipOrgUnitIds(MeProfile profile) {
    final ids = <String>{};
    for (final membership in profile.memberships) {
      final id = (membership['OrgUnitId'] ?? membership['orgUnitId'] ?? '')
          .toString()
          .trim();
      if (id.isNotEmpty) {
        ids.add(id);
      }
    }
    return ids;
  }
}
