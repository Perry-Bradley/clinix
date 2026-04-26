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
          if (consultationId.isEmpty) return;
          // Push the video screen on the same Agora channel.
          appRouter.push(
            '/incoming-call?consultation_id=$consultationId&caller_name=${Uri.encodeComponent(callerName)}&audio_only=$audioOnly&auto_accept=1',
          );
          break;
        case Event.actionCallDecline:
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          // No-op for now; backend doesn't track decline state yet.
          break;
        default:
          break;
      }
    });
  }

  /// Drop any active CallKit notifications for this consultation. Used when
  /// the call connects on the other side or the user manually leaves.
  static Future<void> endCall(String consultationId) async {
    try {
      await FlutterCallkitIncoming.endCall(consultationId);
    } catch (_) {}
  }
}
