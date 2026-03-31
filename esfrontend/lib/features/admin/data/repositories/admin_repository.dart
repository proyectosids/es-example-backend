import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> listUsersByScope({
    required String orgUnitId,
  }) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/users',
      queryParameters: <String, dynamic>{'orgUnitId': orgUnitId},
    );

    final rows = response.data ?? const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listRoles() async {
    final response = await _apiClient.dio.get<List<dynamic>>('/roles');
    final rows = response.data ?? const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listOrgUnits({
    String? parentOrgUnitId,
    String? orgUnitId,
  }) async {
    final params = <String, dynamic>{};
    if ((parentOrgUnitId ?? '').trim().isNotEmpty) {
      params['parentOrgUnitId'] = parentOrgUnitId;
    } else if ((orgUnitId ?? '').trim().isNotEmpty) {
      params['orgUnitId'] = orgUnitId;
    }

    final response = await _apiClient.dio.get<List<dynamic>>(
      '/org-units',
      queryParameters: params.isEmpty ? null : params,
    );
    final rows = response.data ?? const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? displayName,
    String? phone,
    String? membershipOrgUnitId,
    String membershipType = 'MEMBER',
    String? roleCode,
    String? scopeOrgUnitId,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'phone': phone,
      'membershipOrgUnitId': membershipOrgUnitId,
      'membershipType': membershipType,
      'roleCode': roleCode,
      'scopeOrgUnitId': scopeOrgUnitId,
    }..removeWhere((key, value) => value == null || value.toString().isEmpty);

    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/users',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> assignRole({
    required String userId,
    required String roleCode,
    required String scopeOrgUnitId,
    String? validFrom,
    String? validTo,
  }) async {
    final payload = <String, dynamic>{
      'roleCode': roleCode,
      'scopeOrgUnitId': scopeOrgUnitId,
      'validFrom': validFrom,
      'validTo': validTo,
    }..removeWhere((key, value) => value == null || value.toString().isEmpty);

    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/users/$userId/roles',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateOrgUnit({
    required String orgUnitId,
    String? name,
    String? path,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'path': path,
      'isActive': isActive,
    }..removeWhere((key, value) => value == null);

    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/org-units/$orgUnitId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  String readableError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = (data['message'] ?? '').toString().trim();
        if (msg.isNotEmpty) return msg;
      }
      if (status == 403) return 'No tienes permiso para esta pantalla.';
      if (status == 401) return 'Sesion invalida o expirada.';
      if (error.response == null) return 'No hay conexion con el backend.';
    }
    return 'Error al cargar datos administrativos.';
  }
}
