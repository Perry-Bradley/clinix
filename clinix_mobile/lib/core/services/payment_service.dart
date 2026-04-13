import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

class PaymentService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: '${ApiConstants.baseUrl}payments/',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ));

  static Future<Map<String, dynamic>> initiate({
    required String appointmentId,
    required String paymentMethod,
    required double amount,
    required String payerPhone,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }
    final response = await _dio.post(
      'initiate/',
      data: {
        'appointment': appointmentId,
        'payment_method': paymentMethod,
        'amount': amount.toStringAsFixed(2),
        'payer_phone': payerPhone,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> getStatus(String paymentId) async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }
    final response = await _dio.get(
      'status/$paymentId/',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
