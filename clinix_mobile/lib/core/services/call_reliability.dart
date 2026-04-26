import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_colors.dart';

/// Universal call-reliability bootstrap. Fires once per install (per logged-in
/// user) to make sure incoming calls actually wake the device on every Android
/// flavour — Pixel + Samsung work out of the box, but Xiaomi / Huawei /
/// Oppo / Vivo aggressively kill background apps unless the user opts the app
/// out of battery optimisation. This prompt is the same one WhatsApp,
/// Telegram and Google Meet show on first launch.
class CallReliability {
  static const _storage = FlutterSecureStorage();
  static const _shownKey = 'call_reliability_prompt_shown_v1';

  /// Show a one-time gentle dialog asking the user to whitelist the app from
  /// battery optimisation. Skipped if not Android, already shown, or already
  /// granted.
  static Future<void> ensureCallReliable(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final already = await _storage.read(key: _shownKey);
    if (already == 'true') return;

    // Skip if the OS has already exempted us.
    try {
      if (await Permission.ignoreBatteryOptimizations.isGranted) {
        await _storage.write(key: _shownKey, value: 'true');
        return;
      }
    } catch (_) {}

    if (!context.mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: const [
          Icon(Icons.phone_in_talk_rounded, color: AppColors.darkBlue500),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Don\u2019t miss a call',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.darkBlue900,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
        ]),
        content: const Text(
          'For Clinix calls to ring even when your phone is locked, please '
          'allow Clinix to run in the background.\n\n'
          'On the next screen, tap "Allow" or pick "Don\u2019t optimise".',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.darkBlue900,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Later',
              style: TextStyle(
                color: AppColors.grey500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue500,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    // Always mark as shown — we don't want to re-prompt the user every time
    // they open the app even if they tapped "Later".
    await _storage.write(key: _shownKey, value: 'true');

    if (accepted != true) return;
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}
  }
}
