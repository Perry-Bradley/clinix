import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

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
      payload: message.data['route'],
    );
  }

  /// Handle when user taps a notification (from background/terminated)
  static void _handleMessageTap(RemoteMessage message) {
    // The route data can be used with GoRouter to navigate
    // e.g. message.data['route'] = '/patient/appointments/123'
    // Navigation would need a global navigator key - handled by the app router
  }

  /// Handle when user taps a local notification (foreground)
  static void _onNotificationTap(NotificationResponse response) {
    // response.payload contains the route if set
    // Navigation would need a global navigator key
  }
}
