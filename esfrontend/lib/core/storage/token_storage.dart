import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kTenantCode = 'auth_tenant_code';
  static const _kUserEmail = 'auth_user_email';
  static const _kUserName = 'auth_user_name';
  static const _kUserId = 'auth_user_id';
  static const _kTenantId = 'auth_tenant_id';
  static const _kSelectedOrgUnitId = 'auth_selected_org_unit_id';
  static const _kProfileJson = 'auth_profile_json';
  static const _kAccessContextJson = 'auth_access_context_json';

  Future<Map<String, String?>> readSession() async {
    final accessToken = await _storage.read(key: _kAccessToken);
    final refreshToken = await _storage.read(key: _kRefreshToken);
    final tenantCode = await _storage.read(key: _kTenantCode);
    final userEmail = await _storage.read(key: _kUserEmail);
    final userName = await _storage.read(key: _kUserName);
    final userId = await _storage.read(key: _kUserId);
    final tenantId = await _storage.read(key: _kTenantId);

    return <String, String?>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tenantCode': tenantCode,
      'userEmail': userEmail,
      'userName': userName,
      'userId': userId,
      'tenantId': tenantId,
      'selectedOrgUnitId': await _storage.read(key: _kSelectedOrgUnitId),
      'profileJson': await _storage.read(key: _kProfileJson),
      'accessContextJson': await _storage.read(key: _kAccessContextJson),
    };
  }

  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String tenantCode,
    required String userEmail,
    String? userName,
    String? userId,
    String? tenantId,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(key: _kTenantCode, value: tenantCode);
    await _storage.write(key: _kUserEmail, value: userEmail);
    await _storage.write(key: _kUserName, value: userName ?? '');
    await _storage.write(key: _kUserId, value: userId ?? '');
    await _storage.write(key: _kTenantId, value: tenantId ?? '');
  }

  Future<void> writeAccessToken(String accessToken) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kTenantCode);
    await _storage.delete(key: _kUserEmail);
    await _storage.delete(key: _kUserName);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kTenantId);
    await _storage.delete(key: _kSelectedOrgUnitId);
    await _storage.delete(key: _kProfileJson);
    await _storage.delete(key: _kAccessContextJson);
  }

  Future<String?> readSelectedOrgUnitId() async {
    return _storage.read(key: _kSelectedOrgUnitId);
  }

  Future<void> writeSelectedOrgUnitId(String orgUnitId) async {
    await _storage.write(key: _kSelectedOrgUnitId, value: orgUnitId);
  }

  Future<void> clearSelectedOrgUnitId() async {
    await _storage.delete(key: _kSelectedOrgUnitId);
  }

  Future<void> writeCachedProfile(Map<String, dynamic> profileJson) async {
    await _storage.write(key: _kProfileJson, value: jsonEncode(profileJson));
  }

  Future<Map<String, dynamic>?> readCachedProfile() async {
    final raw = await _storage.read(key: _kProfileJson);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCachedAccessContext(
    Map<String, dynamic> accessContextJson,
  ) async {
    await _storage.write(
      key: _kAccessContextJson,
      value: jsonEncode(accessContextJson),
    );
  }

  Future<Map<String, dynamic>?> readCachedAccessContext() async {
    final raw = await _storage.read(key: _kAccessContextJson);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedAccessContext() async {
    await _storage.delete(key: _kProfileJson);
    await _storage.delete(key: _kAccessContextJson);
  }
}
