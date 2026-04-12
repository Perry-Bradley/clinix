import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'health_metric_service.dart';

class ActivityService {
  final Ref _ref;
  StreamSubscription<StepCount>? _stepCountSubscription;
  int _todayBaseSteps = 0;
  int _currentSteps = 0;

  ActivityService(this._ref);

  Stream<int> get stepCountStream {
    return Pedometer.stepCountStream.transform(
      StreamTransformer<StepCount, int>.fromHandlers(
        handleData: (event, sink) {
          if (_todayBaseSteps == 0) {
            _todayBaseSteps = event.steps;
          }
          _currentSteps = event.steps - _todayBaseSteps;
          if (_currentSteps % 100 == 0) {
            _syncWithBackend();
          }
          sink.add(_currentSteps);
        },
        handleError: (_, __, sink) {
          sink.add(_currentSteps);
        },
      ),
    );
  }

  Future<void> init() async {
    if (await Permission.activityRecognition.request().isGranted) {
      // Start listening
    }
  }

  void _syncWithBackend() {
    unawaited(
      _ref.read(healthMetricServiceProvider).syncActivity(
        steps: _currentSteps,
        distanceKm: _currentSteps * 0.0008,
      ).catchError((_) {}),
    );
  }

  void dispose() {
    _stepCountSubscription?.cancel();
  }
}

final activityServiceProvider = Provider<ActivityService>((ref) {
  return ActivityService(ref);
});

final stepCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(activityServiceProvider);
  return service.stepCountStream;
});
