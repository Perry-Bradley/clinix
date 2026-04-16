import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

class DoctorService {
  static const _baseUrl = ApiConstants.providers;
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: '${ApiConstants.baseUrl}${ApiConstants.providers}',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final token = await AuthService.getAccessToken();
    final response = await _dio.patch(
      'profile/',
      data: data,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data;
  }

  static Future<void> updateSchedule(List<Map<String, dynamic>> schedules) async {
    final token = await AuthService.getAccessToken();
    await _dio.post(
      'schedule/',
      data: {'schedules': schedules},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  static Future<void> updateLocation(Map<String, dynamic> locationData) async {
    final token = await AuthService.getAccessToken();
    // Assuming backend endpoint handles both residence and clinic via location_type
    // We update ApiConstants to include locations if needed, or use full path
    final locationsDio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl, // Base for the whole API
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));
    await locationsDio.post('locations/provider/', data: locationData);
  }

  static Future<List<dynamic>> getNearbyDoctors({double? lat, double? lng}) async {
    try {
      final token = await AuthService.getAccessToken();
      final response = await _dio.get(
        'nearby/',
        queryParameters: {
          // 'available': 'true',
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.data is List) return response.data;
      if (response.data is Map && response.data.containsKey('results')) {
        return response.data['results'];
      }
      return [];
    } catch (e) {
      print('Error fetching nearby doctors: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getTopDoctors() async {
    try {
      final token = await AuthService.getAccessToken();
      final response = await _dio.get(
        'nearby/',
        queryParameters: {'limit': 5},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.data is List) return response.data;
      if (response.data is Map && response.data.containsKey('results')) {
        return response.data['results'];
      }
      return [];
    } catch (e) {
      print('Error fetching top doctors: $e');
      return []; // Return empty list rather than throwing for UI stability
    }
  }
}
