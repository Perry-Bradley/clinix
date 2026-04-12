import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class HealthMetricService {
  final Dio _dio;

  HealthMetricService(this._dio);

  Future<Map<String, dynamic>> getHealthSummary() async {
    try {
      final response = await _dio.get('health/summary/');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveHeartRate({
    required int bpm, 
    double? hrvMs, 
    int? respiratoryRate
  }) async {
    try {
      await _dio.post('health/heart-rate/', data: {
        'bpm': bpm,
        'hrv_ms': hrvMs,
        'respiratory_rate': respiratoryRate,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncActivity({required int steps, required double distanceKm}) async {
    try {
      await _dio.post('health/activity/sync/', data: {
        'steps': steps,
        'distance_km': distanceKm,
      });
    } catch (e) {
      rethrow;
    }
  }
}

final healthMetricServiceProvider = Provider<HealthMetricService>((ref) {
  return HealthMetricService(ref.watch(dioProvider));
});

final healthSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(healthMetricServiceProvider).getHealthSummary();
});
