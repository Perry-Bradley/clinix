import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

/// Production direct messaging between any two users (patient ↔ provider).
/// Uses WebSocket for live delivery + REST for history and starting conversations.
class DirectChatService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: '${ApiConstants.baseUrl}dchat/',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _ctrl = StreamController.broadcast();

  Stream<Map<String, dynamic>> get messages => _ctrl.stream;

  // ─── REST: start / list conversations ───────────────────────────────────

  /// Get or create a conversation with a provider by their user_id (provider_id).
  static Future<Map<String, dynamic>> startWithProvider(String providerId) async {
    final token = await AuthService.getAccessToken();
    final res = await _dio.post(
      'start/$providerId/',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<Map<String, dynamic>> startWithPeer(String peerId) async {
    final token = await AuthService.getAccessToken();
    final res = await _dio.post(
      'start/',
      data: {'peer_id': peerId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<List<Map<String, dynamic>>> listConversations() async {
    final token = await AuthService.getAccessToken();
    final res = await _dio.get(
      'conversations/',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = res.data;
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchMessages(String conversationId) async {
    final token = await AuthService.getAccessToken();
    final res = await _dio.get(
      '$conversationId/messages/',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = res.data;
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  static Future<Map<String, dynamic>> sendViaHttp(
    String conversationId, {
    required String content,
    String messageType = 'text',
    String? fileUrl,
    String? fileName,
  }) async {
    final token = await AuthService.getAccessToken();
    final res = await _dio.post(
      '$conversationId/messages/',
      data: {
        'content': content,
        'message_type': messageType,
        if (fileUrl != null) 'file_url': fileUrl,
        if (fileName != null) 'file_name': fileName,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ─── WebSocket: live delivery ───────────────────────────────────────────

  void connect(String conversationId, String accessToken) {
    final base = ApiConstants.baseUrl.replaceFirst('/api/v1', '').replaceFirst('/api/v1/', '');
    final wsUrl = '${base.replaceFirst('http', 'ws')}/ws/dchat/$conversationId/?token=$accessToken';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String);
          if (decoded is Map) _ctrl.add(Map<String, dynamic>.from(decoded));
        } catch (_) {}
      },
      onError: (e) {},
      onDone: () {},
    );
  }

  void send(String content, {String messageType = 'text', String? fileUrl, String? fileName}) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'content': content,
      'message_type': messageType,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileName != null) 'file_name': fileName,
    }));
  }

  void dispose() {
    _channel?.sink.close();
    _ctrl.close();
  }
}
