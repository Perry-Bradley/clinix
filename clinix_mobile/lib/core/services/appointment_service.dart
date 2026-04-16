import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

class AppointmentService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: '${ApiConstants.baseUrl}${ApiConstants.appointments}',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static Future<List<String>> getAvailableSlots(String providerId, DateTime date) async {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final response = await _dio.get('available-slots/', queryParameters: {
      'provider_id': providerId,
      'date': dateStr,
    });
    return List<String>.from(response.data['available_slots'] as List);
  }

  static String _apiAppointmentType(String t) {
    switch (t) {
      case 'in_person':
        return 'in-person';
      case 'video':
      case 'audio':
      default:
        return 'virtual';
    }
  }

  static Future<Map<String, dynamic>> createAppointment({
    required String providerId,
    required DateTime scheduledAt,
    required String appointmentType,
  }) async {
    final token = await AuthService.getAccessToken();
    final response = await _dio.post(
      '',
      data: {
        'provider': providerId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'appointment_type': _apiAppointmentType(appointmentType),
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<List<Map<String, dynamic>>> getMyAppointments() async {
    final token = await AuthService.getAccessToken();
    final response = await _dio.get(
      '',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data;
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<Map<String, dynamic>> getAppointment(String appointmentId) async {
    final token = await AuthService.getAccessToken();
    final response = await _dio.get(
      '$appointmentId/',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    final token = await AuthService.getAccessToken();
    await _dio.patch(
      '$appointmentId/',
      data: {'status': 'cancelled', if (reason != null) 'cancellation_reason': reason},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
