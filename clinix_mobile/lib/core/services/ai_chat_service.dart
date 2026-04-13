import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

class AiChatService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${ApiConstants.baseUrl}ai/',
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );

  static Future<Map<String, dynamic>> startChat() async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: 'chat/start/'),
        message: 'Not signed in',
      );
    }
    final response = await _dio.post<Map<String, dynamic>>('chat/start/');
    return Map<String, dynamic>.from(response.data ?? {});
  }

  static Future<String> sendMessage(String sessionId, String message, {String? imageBase64}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'chat/$sessionId/message/',
      data: {
        'message': message,
        if (imageBase64 != null && imageBase64.trim().isNotEmpty) 'image': imageBase64,
      },
    );
    final r = response.data?['reply'];
    final text = r?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty reply from Clinix AI',
        type: DioExceptionType.badResponse,
      );
    }
    return text;
  }

  static Future<Map<String, dynamic>> completeChat(String sessionId) async {
    final response = await _dio.post<Map<String, dynamic>>('chat/$sessionId/complete/');
    return Map<String, dynamic>.from(response.data ?? {});
  }

  static Future<Map<String, dynamic>> getChatHistory(String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>('chat/$sessionId/');
    return Map<String, dynamic>.from(response.data ?? {});
  }
}
