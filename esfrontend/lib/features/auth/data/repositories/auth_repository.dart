import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/auth_session.dart';

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthSession> login({
    required String tenantCode,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: <String, dynamic>{
        'tenantCode': tenantCode,
        'email': email,
        'password': password,
      },
    );

    final payload = response.data ?? <String, dynamic>{};
    final session = AuthSession.fromLoginResponse(payload);
    if (!session.isValid) {
      throw Exception('Respuesta de login incompleta');
    }
    return session;
  }

  Future<String> refresh({required String refreshToken}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: <String, dynamic>{'refreshToken': refreshToken},
      options: Options(extra: const <String, Object?>{'skipAuth': true}),
    );

    final token = (response.data?['accessToken'] ?? '').toString();
    if (token.isEmpty) {
      throw Exception('No se recibio accessToken en refresh');
    }
    return token;
  }

  Future<MeProfile> fetchMe({required String accessToken}) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/me',
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        extra: const <String, Object?>{'skipAuth': true},
      ),
    );
    return MeProfile.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<String>> fetchPermissions({
    required String accessToken,
    String? orgUnitId,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/me/permissions',
      queryParameters: orgUnitId == null
          ? null
          : <String, dynamic>{'orgUnitId': orgUnitId},
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        extra: const <String, Object?>{'skipAuth': true},
      ),
    );

    final list = (response.data?['permissions'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return list;
  }

  Future<List<String>> fetchScreens({
    required String accessToken,
    String? orgUnitId,
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/me/screens',
      queryParameters: orgUnitId == null
          ? null
          : <String, dynamic>{'orgUnitId': orgUnitId},
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        extra: const <String, Object?>{'skipAuth': true},
      ),
    );

    final rows = (response.data?['screens'] as List<dynamic>? ?? const []);
    return rows
        .whereType<Map>()
        .map((e) => (e['ScreenKey'] ?? e['screenKey'] ?? '').toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }
}
