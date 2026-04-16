import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clinix_mobile/core/constants/api_constants.dart';
import 'package:clinix_mobile/core/services/auth_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthService.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) async {
        // Auto-refresh token on 401
        if (e.response?.statusCode == 401) {
          try {
            final newToken = await AuthService.refreshAccessToken();
            if (newToken != null) {
              // Retry the original request with the new token
              final opts = e.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            }
          } catch (_) {
            // Refresh failed - token is fully expired, user needs to re-login
          }
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
});
