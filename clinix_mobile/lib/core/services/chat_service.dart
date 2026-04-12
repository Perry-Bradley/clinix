import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ChatService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(String consultationId, String accessToken) {
    // Correct URL to match backend routing: ws://host:port/ws/consultation/UUID/chat/
    final baseUrl = ApiConstants.baseUrl.replaceFirst('/api/v1', '');
    final wsUrl = baseUrl.replaceFirst('http', 'ws') + '/ws/consultation/$consultationId/chat/?token=$accessToken';
    
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    _channel!.stream.listen(
      (data) {
        final decoded = jsonDecode(data);
        _messageController.add(decoded);
      },
      onError: (err) => print('Chat WebSocket Error: $err'),
      onDone: () => print('Chat WebSocket Closed'),
    );
  }

  void sendMessage(String message, {String type = 'text', String? fileUrl, String? fileName}) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'message': message,
        'message_type': type,
        'file_url': fileUrl,
        'file_name': fileName,
      }));
    }
  }

  String _basename(String filePath) {
    final n = filePath.replaceAll(r'\', '/');
    final i = n.lastIndexOf('/');
    return i >= 0 ? n.substring(i + 1) : n;
  }

  Future<Map<String, dynamic>> uploadMedia(String consultationId, String token, String filePath, String type) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.consultations}$consultationId/upload/');
    
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['message_type'] = type;
    
    request.files.add(await http.MultipartFile.fromPath(
      'file', 
      filePath,
      filename: _basename(filePath),
    ));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    if (response.statusCode == 201) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Failed to upload media: $responseBody');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String consultationId, String token) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.consultations}$consultationId/messages/');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch messages');
    }
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
