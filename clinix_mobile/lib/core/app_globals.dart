import 'package:flutter/material.dart';

/// Global messenger key so we can show SnackBars from anywhere — including
/// after a screen has been popped (e.g. the post-call AI-report result, which
/// fires once the doctor has already left the call screen).
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
