import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class HealthConnectService {
  static final Health _health = Health();
  static bool _authorized = false;

  static const _readTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  ];

  static const _writeTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
  ];

  /// Check if Health Connect is available on this device
  static Future<bool> isAvailable() async {
    try {
      final status = await Health().getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      debugPrint('[HealthConnect] Availability check failed: $e');
      return false;
    }
  }

  /// Request permissions for reading health data
  static Future<bool> requestPermissions() async {
    try {
      final permissions = _readTypes.map((t) => HealthDataAccess.READ).toList()
        ..addAll(_writeTypes.map((t) => HealthDataAccess.WRITE));
      final allTypes = [..._readTypes, ..._writeTypes];

      _authorized = await _health.requestAuthorization(
        allTypes,
        permissions: permissions,
      );
      debugPrint('[HealthConnect] Authorization: $_authorized');
      return _authorized;
    } catch (e) {
      debugPrint('[HealthConnect] Permission request failed: $e');
      return false;
    }
  }

  /// Get the latest heart rate from the last 24 hours
  static Future<int?> getLatestHeartRate() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 24));
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: now,
      );
      if (data.isEmpty) return null;
      data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final val = data.first.value;
      if (val is NumericHealthValue) return val.numericValue.toInt();
      return null;
    } catch (e) {
      debugPrint('[HealthConnect] Heart rate fetch failed: $e');
      return null;
    }
  }

  /// Get today's total steps
  static Future<int> getTodaySteps() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(start, now);
      return steps ?? 0;
    } catch (e) {
      debugPrint('[HealthConnect] Steps fetch failed: $e');
      return 0;
    }
  }

  /// Get latest blood oxygen (SpO2)
  static Future<double?> getLatestSpO2() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 24));
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_OXYGEN],
        startTime: start,
        endTime: now,
      );
      if (data.isEmpty) return null;
      data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final val = data.first.value;
      if (val is NumericHealthValue) return val.numericValue.toDouble();
      return null;
    } catch (e) {
      debugPrint('[HealthConnect] SpO2 fetch failed: $e');
      return null;
    }
  }

  /// Get latest blood pressure
  static Future<Map<String, int>?> getLatestBloodPressure() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 48));
      final systolicData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
        startTime: start,
        endTime: now,
      );
      final diastolicData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        startTime: start,
        endTime: now,
      );
      if (systolicData.isEmpty || diastolicData.isEmpty) return null;
      systolicData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      diastolicData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final sys = systolicData.first.value;
      final dia = diastolicData.first.value;
      if (sys is NumericHealthValue && dia is NumericHealthValue) {
        return {'systolic': sys.numericValue.toInt(), 'diastolic': dia.numericValue.toInt()};
      }
      return null;
    } catch (e) {
      debugPrint('[HealthConnect] BP fetch failed: $e');
      return null;
    }
  }

  /// Write heart rate from camera measurement to Health Connect
  static Future<bool> writeHeartRate(int bpm) async {
    try {
      final now = DateTime.now();
      return await _health.writeHealthData(
        value: bpm.toDouble(),
        type: HealthDataType.HEART_RATE,
        startTime: now.subtract(const Duration(seconds: 30)),
        endTime: now,
      );
    } catch (e) {
      debugPrint('[HealthConnect] Write HR failed: $e');
      return false;
    }
  }

  /// Get a full health summary — tries Health Connect first, returns what's available
  static Future<Map<String, dynamic>> getHealthSummary() async {
    final available = await isAvailable();
    if (!available || !_authorized) {
      return {'source': 'none'};
    }

    final heartRate = await getLatestHeartRate();
    final steps = await getTodaySteps();
    final spo2 = await getLatestSpO2();
    final bp = await getLatestBloodPressure();

    return {
      'source': 'health_connect',
      'heart_rate': heartRate,
      'steps': steps,
      'spo2': spo2,
      'blood_pressure': bp,
    };
  }
}
