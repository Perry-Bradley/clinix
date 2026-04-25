import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  String? _conversationId;
  String? _accessToken;
  bool _wsConnected = false;

  void connect(String conversationId, String accessToken) {
    _conversationId = conversationId;
    _accessToken = accessToken;
    _connectWs(conversationId, accessToken);
  }

  void _connectWs(String conversationId, String accessToken) {
    final base = ApiConstants.baseUrl.replaceFirst('/api/v1', '').replaceFirst('/api/v1/', '');
    final wsUrl = '${base.replaceFirst('http', 'ws')}/ws/dchat/$conversationId/?token=$accessToken';
    debugPrint('[DirectChat] WS connecting to: $wsUrl');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsConnected = true;
      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is Map) _ctrl.add(Map<String, dynamic>.from(decoded));
          } catch (e) {
            debugPrint('[DirectChat] WS parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('[DirectChat] WS error: $e');
          _wsConnected = false;
        },
        onDone: () {
          debugPrint('[DirectChat] WS closed');
          _wsConnected = false;
        },
      );
    } catch (e) {
      debugPrint('[DirectChat] WS connect failed: $e');
      _wsConnected = false;
    }
  }

  /// Send via WebSocket if connected, otherwise fall back to HTTP POST
  Future<void> send(String content, {String messageType = 'text', String? fileUrl, String? fileName}) async {
    if (_wsConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode({
          'content': content,
          'message_type': messageType,
          if (fileUrl != null) 'file_url': fileUrl,
          if (fileName != null) 'file_name': fileName,
        }));
        debugPrint('[DirectChat] Sent via WS');
        return;
      } catch (e) {
        debugPrint('[DirectChat] WS send failed, falling back to HTTP: $e');
        _wsConnected = false;
      }
    }

    // HTTP fallback
    if (_conversationId != null) {
      debugPrint('[DirectChat] Sending via HTTP fallback');
      try {
        final result = await sendViaHttp(
          _conversationId!,
          content: content,
          messageType: messageType,
          fileUrl: fileUrl,
          fileName: fileName,
        );
        _ctrl.add(Map<String, dynamic>.from(result));
      } catch (e) {
        debugPrint('[DirectChat] HTTP send also failed: $e');
      }
    }
  }

  void dispose() {
    _channel?.sink.close();
    _ctrl.close();
  }
}
