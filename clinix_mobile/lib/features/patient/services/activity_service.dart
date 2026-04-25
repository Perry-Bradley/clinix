import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'health_metric_service.dart';

class ActivityService {
  final Ref _ref;
  StreamSubscription<StepCount>? _stepCountSubscription;
  int _todayBaseSteps = 0;
  int _currentSteps = 0;
  bool _initialized = false;
  bool _goalNotified = false;
  int _stepGoal = 10000;
  static const _storage = FlutterSecureStorage();

  ActivityService(this._ref);

  Stream<int> get stepCountStream {
    return Pedometer.stepCountStream.transform(
      StreamTransformer<StepCount, int>.fromHandlers(
        handleData: (event, sink) {
          if (_todayBaseSteps == 0) _todayBaseSteps = event.steps;
          _currentSteps = event.steps - _todayBaseSteps;
          if (_currentSteps > 0 && _currentSteps % 10 == 0) _syncWithBackend();
          sink.add(_currentSteps);
        },
        handleError: (error, trace, sink) {
          debugPrint('[Steps] Stream error: $error');
          sink.add(_currentSteps);
        },
      ),
    );
  }

  Future<void> init() async {
    if (_initialized) return;

    // Load step goal
    final savedGoal = await _storage.read(key: 'step_goal');
    _stepGoal = int.tryParse(savedGoal ?? '') ?? 10000;

    final status = await Permission.activityRecognition.request();
    debugPrint('[Steps] Permission status: $status');

    if (!status.isGranted) {
      debugPrint('[Steps] Permission denied — cannot track steps');
      return;
    }

    _stepCountSubscription?.cancel();

    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        (event) {
          if (_todayBaseSteps == 0) {
            _todayBaseSteps = event.steps;
            debugPrint('[Steps] Base steps set to: $_todayBaseSteps');
          }
          _currentSteps = event.steps - _todayBaseSteps;
          debugPrint('[Steps] Current: $_currentSteps (raw: ${event.steps})');
          if (_currentSteps > 0 && _currentSteps % 10 == 0) _syncWithBackend();
          // Goal reached notification
          if (_currentSteps >= _stepGoal && !_goalNotified) {
            _goalNotified = true;
            _sendGoalNotification();
          }
        },
        onError: (error) {
          debugPrint('[Steps] Pedometer error: $error');
          // Retry after 5 seconds on error
          Future.delayed(const Duration(seconds: 5), () {
            if (!_initialized) return;
            _initialized = false;
            init();
          });
        },
        cancelOnError: false,
      );
      _initialized = true;
      debugPrint('[Steps] Pedometer listener started successfully');
    } catch (e) {
      debugPrint('[Steps] Failed to start pedometer: $e');
    }
  }

  Future<void> _sendGoalNotification() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.show(
        id: 42,
        title: 'Step Goal Reached!',
        body: 'You\'ve hit $_stepGoal steps today. Keep it up!',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'steps_goal',
            'Step Goal',
            channelDescription: 'Notification when daily step goal is reached',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
      debugPrint('[Steps] Goal notification sent');
    } catch (e) {
      debugPrint('[Steps] Goal notification failed: $e');
    }
  }

  void _syncWithBackend() {
    debugPrint('[Steps] Syncing $_currentSteps steps to backend');
    unawaited(
      _ref.read(healthMetricServiceProvider).syncActivity(
        steps: _currentSteps,
        distanceKm: _currentSteps * 0.0008,
      ).then((_) {
        _ref.invalidate(healthSummaryProvider);
        debugPrint('[Steps] Synced successfully');
      }).catchError((e) {
        debugPrint('[Steps] Sync failed: $e');
      }),
    );
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _initialized = false;
  }
}

final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService(ref);
});

final stepCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(activityServiceProvider);
  return service.stepCountStream;
});
