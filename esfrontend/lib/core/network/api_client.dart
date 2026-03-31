import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    Future<String?> Function()? getAccessToken,
    Future<String?> Function()? refreshAccessToken,
    Future<void> Function()? onUnauthorized,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 20),
           receiveTimeout: const Duration(seconds: 20),
         ),
       ) {
    if (getAccessToken != null) {
      dio.interceptors.add(
        _AuthInterceptor(
          dio: dio,
          getAccessToken: getAccessToken,
          refreshAccessToken: refreshAccessToken,
          onUnauthorized: onUnauthorized,
        ),
      );
    }
  }

  final Dio dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({
    required this.dio,
    required this.getAccessToken,
    required this.refreshAccessToken,
    required this.onUnauthorized,
  });

  final Dio dio;
  final Future<String?> Function() getAccessToken;
  final Future<String?> Function()? refreshAccessToken;
  final Future<void> Function()? onUnauthorized;

  static const _kSkipAuth = 'skipAuth';
  static const _kRetried = 'authRetried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra[_kSkipAuth] == true;
    if (!skipAuth) {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final unauthorized = err.response?.statusCode == 401;
    final alreadyRetried = request.extra[_kRetried] == true;
    final skipAuth = request.extra[_kSkipAuth] == true;

    if (!unauthorized ||
        alreadyRetried ||
        skipAuth ||
        refreshAccessToken == null) {
      if (unauthorized && onUnauthorized != null) {
        await onUnauthorized!();
      }
      handler.next(err);
      return;
    }

    try {
      final refreshed = await refreshAccessToken!();
      if (refreshed == null || refreshed.isEmpty) {
        if (onUnauthorized != null) await onUnauthorized!();
        handler.next(err);
        return;
      }

      final retried = await _retryRequest(request, refreshed);
      handler.resolve(retried);
    } catch (_) {
      if (onUnauthorized != null) await onUnauthorized!();
      handler.next(err);
    }
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions request,
    String accessToken,
  ) {
    final newHeaders = Map<String, dynamic>.from(request.headers)
      ..['Authorization'] = 'Bearer $accessToken';
    final newExtra = Map<String, dynamic>.from(request.extra)
      ..[_kRetried] = true;

    final options = Options(
      method: request.method,
      headers: newHeaders,
      responseType: request.responseType,
      contentType: request.contentType,
      extra: newExtra,
      followRedirects: request.followRedirects,
      receiveDataWhenStatusError: request.receiveDataWhenStatusError,
      validateStatus: request.validateStatus,
      sendTimeout: request.sendTimeout,
      receiveTimeout: request.receiveTimeout,
      listFormat: request.listFormat,
    );

    return dio.request<dynamic>(
      request.path,
      data: request.data,
      queryParameters: request.queryParameters,
      options: options,
      cancelToken: request.cancelToken,
      onReceiveProgress: request.onReceiveProgress,
      onSendProgress: request.onSendProgress,
    );
  }
}
