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

  /// Pass either [appointmentId] (existing booking, e.g. doctor consult) OR
  /// [pendingBooking] (pay-first service flow — server materialises the
  /// Appointment when the Campay charge succeeds).
  static Future<Map<String, dynamic>> initiate({
    String? appointmentId,
    Map<String, dynamic>? pendingBooking,
    required String paymentMethod,
    required double amount,
    required String payerPhone,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }
    final body = <String, dynamic>{
      'payment_method': paymentMethod,
      'amount': amount.toStringAsFixed(2),
      'payer_phone': payerPhone,
    };
    if (appointmentId != null && appointmentId.isNotEmpty) {
      body['appointment'] = appointmentId;
    }
    if (pendingBooking != null && pendingBooking.isNotEmpty) {
      body['pending_booking'] = pendingBooking;
    }
    final response = await _dio.post(
      'initiate/',
      data: body,
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
