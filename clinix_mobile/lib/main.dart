import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'core/theme/app_theme.dart';
import 'core/app_globals.dart';
import 'core/constants/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/call_handler.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Top-level FCM handler that fires when a push lands while the app is in
/// the background OR fully terminated. We watch for `type=incoming_call`
/// and immediately trigger the native CallKit UI so the device wakes up,
/// rings, and shows the lock-screen call screen — same as WhatsApp.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Required because this runs in a separate isolate.
  await Firebase.initializeApp();

  if (message.data['type']?.toString() == 'incoming_call') {
    await CallHandler.showIncomingCall(
      consultationId: message.data['consultation_id']?.toString() ?? '',
      callerName: message.data['caller_name']?.toString() ?? 'Caller',
      callerPhoto: message.data['caller_photo']?.toString(),
      audioOnly: message.data['audio_only']?.toString().toLowerCase() == 'true',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Background isolate handler — must be registered BEFORE the app reads
  // FirebaseMessaging events, so register it first.
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  // Initialize push notifications (request permission + register FCM token)
  await NotificationService.initialize();

  // Native CallKit accept/decline events route to the in-app call screen.
  CallHandler.attachEventListener();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found. Ensure it exists in the root directory.");
  }

  // Enable Hybrid Composition for Google Maps on Android
  if (Platform.isAndroid) {
    final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
    }
  }

  runApp(
    const ProviderScope(
      child: ClinixApp(),
    ),
  );

  // Cold-start backstop: if the app was launched by accepting an incoming call
  // on the native CallKit screen, the live accept event can be missed. Once the
  // UI and the auth redirect have settled, route into any accepted call.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(milliseconds: 1500), CallHandler.routePendingCall);
  });
}

class ClinixApp extends StatelessWidget {
  const ClinixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Clinix',
      theme: AppTheme.light,
      routerConfig: appRouter,
      scaffoldMessengerKey: rootMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
