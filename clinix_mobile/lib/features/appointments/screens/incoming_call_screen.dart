import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';

import '../../../core/theme/app_colors.dart';
import 'video_consultation_screen.dart';

/// Full-screen incoming-call UI rendered when an `incoming_call` FCM lands
/// on the device. Plays the system ringtone, vibrates, and gives the user
/// 30 seconds to accept or decline before auto-dismissing.
class IncomingCallScreen extends StatefulWidget {
  final String consultationId;
  final String callerName;
  final String? callerPhoto;
  final bool audioOnly;

  const IncomingCallScreen({
    super.key,
    required this.consultationId,
    required this.callerName,
    this.callerPhoto,
    this.audioOnly = false,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _startRinging();
    // Auto-dismiss after 30s if neither party acts.
    _autoDismiss = Timer(const Duration(seconds: 30), () {
      if (mounted) _decline(autoMissed: true);
    });
  }

  Future<void> _startRinging() async {
    try {
      FlutterRingtonePlayer().playRingtone(asAlarm: false);
    } catch (_) {}
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 1000, 500, 1000, 500, 1000], repeat: 0);
      }
    } catch (_) {}
  }

  Future<void> _stopRinging() async {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _pulse.dispose();
    _stopRinging();
    super.dispose();
  }

  void _accept() {
    _autoDismiss?.cancel();
    _stopRinging();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VideoConsultationScreen(
          consultationId: widget.consultationId,
          doctorName: widget.callerName,
          audioOnly: widget.audioOnly,
        ),
      ),
    );
  }

  void _decline({bool autoMissed = false}) {
    _autoDismiss?.cancel();
    _stopRinging();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  String _initials(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'^(Dr\.?|Doctor|Mr\.?|Mrs\.?|Ms\.?)\s+',
            caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '?';
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                widget.audioOnly ? 'Incoming voice call' : 'Incoming video call',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Clinix',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Pulsing avatar ring.
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final t = _pulse.value;
                  return SizedBox(
                    width: 200, height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 160 + 60 * t,
                          height: 160 + 60 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity((1 - t) * 0.18),
                          ),
                        ),
                        Container(
                          width: 130, height: 130,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.darkBlue500,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _initials(widget.callerName),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              Text(
                widget.callerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'is calling you...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white60,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallActionButton(
                    color: const Color(0xFFEF4444),
                    icon: Icons.call_end_rounded,
                    label: 'Decline',
                    onTap: () => _decline(),
                  ),
                  _CallActionButton(
                    color: const Color(0xFF22C55E),
                    icon: Icons.call_rounded,
                    label: 'Accept',
                    onTap: _accept,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CallActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 76, height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
