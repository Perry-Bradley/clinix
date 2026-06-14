import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';
import 'call_handler.dart';
import '../constants/app_router.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // ─── Local notifications setup ────────────────────────────────────────
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel for high-priority notifications
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'clinix_high',
        'Clinix Notifications',
        description: 'Appointment reminders, payment updates, and provider alerts',
        importance: Importance.high,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // ─── Firebase messaging permissions ───────────────────────────────────
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _registerToken();
    }

    // ─── Foreground messages → show as local notification ─────────────────
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // ─── Background/terminated tap handler ────────────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from a terminated-state notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await AuthService.saveFcmToken(newToken);
    });
  }

  /// Force-register the FCM token. Call this after successful login.
  static Future<void> registerToken() async => _registerToken();

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await AuthService.saveFcmToken(token);
      }
    } catch (e) {
      // Silently fail - token will be registered on next app launch
    }
  }

  /// Show a visible notification banner when a message arrives while app is open
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    // Incoming call: hand straight to CallKit so the device rings + the
    // user sees the native call UI even if the app is in foreground.
    if (message.data['type']?.toString() == 'incoming_call') {
      await CallHandler.showIncomingCall(
        consultationId: message.data['consultation_id']?.toString() ?? '',
        callerName: message.data['caller_name']?.toString() ?? 'Caller',
        callerPhoto: message.data['caller_photo']?.toString(),
        audioOnly: message.data['audio_only']?.toString().toLowerCase() == 'true',
      );
      return;
    }
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'clinix_high',
      'Clinix Notifications',
      channelDescription: 'Appointment reminders, payment updates, and provider alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Clinix',
      body: notification.body ?? '',
      notificationDetails: details,
      // Carry the FULL data map (JSON) so a foreground tap can route by type
      // — exactly like a background tap. Previously we only passed
      // data['route'], so types that route by data (AI report drafts,
      // prescriptions, appointments…) had a null payload and did nothing.
      payload: jsonEncode(message.data),
    );
  }

  /// Handle when user taps a notification (from background/terminated)
  static void _handleMessageTap(RemoteMessage message) {
    _routeFromData(message.data);
  }

  /// Handle when user taps a local notification. Payloads are either a
  /// plain route ('/x') or prefixed like 'medreminder:/x'.
  static void _onNotificationTap(NotificationResponse response) {
    try {
      var payload = response.payload ?? '';
      if (payload.isEmpty) return;
      // Foreground FCM taps carry the full data map as JSON — route by type
      // just like a background tap.
      if (payload.startsWith('{')) {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          _routeFromData(Map<String, dynamic>.from(decoded));
        }
        return;
      }
      final colon = payload.indexOf(':');
      if (!payload.startsWith('/') && colon > 0) {
        payload = payload.substring(colon + 1);
      }
      if (payload.startsWith('/')) {
        appRouter.push(payload);
      }
    } catch (_) {
      // Routing is best-effort — never crash the notification handler.
    }
  }

  /// Map an incoming notification's `data` payload to a GoRouter destination.
  /// Backend types we currently emit:
  ///   - prescription   → /patient/prescriptions
  ///   - medical_record → AI-draft path opens the doctor's review form,
  ///                      otherwise the patient's records list
  ///   - referral       → /patient/medical-records (referrals show there)
  ///   - consultation   → direct chat (data.route already set)
  ///   - appointment    → /appointments/<id>
  static void _routeFromData(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString() ?? '';
      // The backend always passes simple maps; FCM ships them as Strings on
      // the device, so we coerce booleans manually.
      final isAiDraft = data['is_ai_draft']?.toString().toLowerCase() == 'true';

      if (type == 'incoming_call') {
        final consultationId = data['consultation_id']?.toString() ?? '';
        if (consultationId.isEmpty) return;
        appRouter.push('/incoming-call', extra: {
          'consultationId': consultationId,
          'callerName': data['caller_name']?.toString() ?? 'Caller',
          'callerPhoto': data['caller_photo']?.toString(),
          'audioOnly': data['audio_only']?.toString().toLowerCase() == 'true',
        });
        return;
      }
      if (type == 'medical_record') {
        final recordId = data['record_id']?.toString();
        if (isAiDraft && recordId != null && recordId.isNotEmpty) {
          appRouter.push('/provider/medical-record/new?aiDraftRecordId=$recordId');
        } else {
          appRouter.push('/patient/medical-records');
        }
        return;
      }
      if (type == 'prescription') {
        appRouter.push('/patient/prescriptions');
        return;
      }
      if (type == 'referral') {
        appRouter.push('/patient/medical-records');
        return;
      }
      if (type == 'appointment') {
        final appointmentId = data['appointment_id']?.toString();
        if (appointmentId != null && appointmentId.isNotEmpty) {
          appRouter.push('/appointments/$appointmentId');
        }
        return;
      }
      // Direct chat / explicit `route` payloads.
      final route = data['route']?.toString();
      if (route != null && route.isNotEmpty) {
        appRouter.push(route);
      }
    } catch (_) {
      // Routing is best-effort — never crash the FCM handler.
    }
  }
}
