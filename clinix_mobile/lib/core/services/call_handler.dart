import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../constants/app_router.dart';

/// Bridges incoming-call FCM payloads to the native CallKit (Android
/// ConnectionService / iOS CallKit) so calls actually wake the device, ring
/// through Do-Not-Disturb, and show on the lock screen — like WhatsApp.
class CallHandler {
  static StreamSubscription<dynamic>? _eventSub;

  /// Show a native incoming-call UI for this consultation. Safe to call from
  /// foreground OR a background isolate (the FCM background handler).
  static Future<void> showIncomingCall({
    required String consultationId,
    required String callerName,
    String? callerPhoto,
    bool audioOnly = false,
  }) async {
    final params = CallKitParams(
      id: consultationId,
      nameCaller: callerName,
      avatar: callerPhoto?.isNotEmpty == true ? callerPhoto : null,
      handle: 'Clinix',
      type: audioOnly ? 0 : 1, // 0 = audio, 1 = video
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed Clinix call',
      ),
      extra: {
        'consultation_id': consultationId,
        'audio_only': audioOnly,
        'caller_name': callerName,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#1B4080',
        actionColor: '#1B4080',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Clinix Calls',
        missedCallNotificationChannelName: 'Clinix Missed Calls',
        isShowCallID: false,
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Wire CallKit accept/decline events to the app's router. Call once at
  /// app boot, on the main isolate.
  static void attachEventListener() {
    _eventSub?.cancel();
    _eventSub = FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;
      final body = event.body is Map ? Map<String, dynamic>.from(event.body) : <String, dynamic>{};
      final extra = body['extra'] is Map
          ? Map<String, dynamic>.from(body['extra'] as Map)
          : <String, dynamic>{};
      final consultationId = (extra['consultation_id'] ?? body['id'] ?? '').toString();
      final callerName = (extra['caller_name'] ?? body['nameCaller'] ?? 'Caller').toString();
      final audioOnly = extra['audio_only'] == true || extra['audio_only']?.toString().toLowerCase() == 'true';

      switch (event.event) {
        case Event.actionCallAccept:
          // Defer briefly so the navigation lands AFTER the app's startup
          // auth-redirect settles — otherwise, on a cold start the call route
          // is overridden and the user lands on the home screen instead of
          // the call.
          Future.delayed(const Duration(milliseconds: 700), () {
            _routeAccepted(consultationId, callerName, audioOnly);
          });
          break;
        case Event.actionCallDecline:
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          if (consultationId.isNotEmpty) endCall(consultationId);
          break;
        default:
          break;
      }
    });
  }

  /// Navigate straight into the call screen (auto-accepting). De-duped so the
  /// live event and the cold-start `activeCalls()` backstop can't double-route.
  static String? _lastRoutedCallId;
  static void _routeAccepted(String consultationId, String callerName, bool audioOnly) {
    if (consultationId.isEmpty) return;
    if (_lastRoutedCallId == consultationId) return;
    _lastRoutedCallId = consultationId;
    appRouter.push(
      '/incoming-call?consultation_id=$consultationId'
      '&caller_name=${Uri.encodeComponent(callerName)}'
      '&audio_only=$audioOnly&auto_accept=1',
    );
  }

  /// Backstop for the cold-start case: when the user accepts on the native
  /// CallKit screen while the app is terminated, the live `onEvent` accept can
  /// fire before the listener is attached and get lost. On startup we query the
  /// active (accepted) calls and route into any that's waiting.
  static Future<void> routePendingCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        final call = Map<String, dynamic>.from(calls.first as Map);
        final extra = call['extra'] is Map
            ? Map<String, dynamic>.from(call['extra'] as Map)
            : <String, dynamic>{};
        final consultationId =
            (extra['consultation_id'] ?? call['id'] ?? '').toString();
        final callerName =
            (extra['caller_name'] ?? call['nameCaller'] ?? 'Caller').toString();
        final audioOnly =
            extra['audio_only']?.toString().toLowerCase() == 'true';
        _routeAccepted(consultationId, callerName, audioOnly);
      }
    } catch (_) {}
  }

  /// Drop any active CallKit notifications for this consultation. Used when
  /// the call connects on the other side or the user manually leaves.
  static Future<void> endCall(String consultationId) async {
    // Allow a later call with the same id to route again.
    if (_lastRoutedCallId == consultationId) _lastRoutedCallId = null;
    try {
      await FlutterCallkitIncoming.endCall(consultationId);
    } catch (_) {}
  }
}
