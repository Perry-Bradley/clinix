import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:clinix_mobile/core/services/auth_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _bgPulseCtrl;
  late AnimationController _introCtrl;
  late AnimationController _featuresCtrl;
  late AnimationController _orbitCtrl;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _taglineFade;
  late Animation<double> _featureSlide;

  @override
  void initState() {
    super.initState();

    _bgPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _featuresCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _introCtrl, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );
    _featureSlide = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(parent: _featuresCtrl, curve: Curves.easeOutCubic),
    );

    _introCtrl.forward().then((_) {
      _featuresCtrl.forward();
      _navigate();
    });
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    const storage = FlutterSecureStorage();
    final onboardingSeen = await storage.read(key: 'onboarding_seen');
    final token = await AuthService.getAccessToken();
    final userType = await AuthService.getUserType();
    if (!mounted) return;
    if (onboardingSeen != 'true') {
      context.go('/onboarding');
    } else if (token == null) {
      context.go('/login');
    } else if (userType == 'unassigned') {
      context.go('/role-selection');
    } else if (userType == 'provider') {
      context.go('/provider/home');
    } else {
      context.go('/patient/home');
    }
  }

  @override
  void dispose() {
    _bgPulseCtrl.dispose();
    _introCtrl.dispose();
    _featuresCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Stack(
        children: [
          // ── Animated background with gradient blobs + grid ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgPulseCtrl,
              builder: (_, __) => CustomPaint(
                painter: _BackgroundPainter(_bgPulseCtrl.value),
              ),
            ),
          ),

          // ── Orbiting medical cross illustration ──
          Positioned(
            top: size.height * 0.14,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 280,
              child: AnimatedBuilder(
                animation: Listenable.merge([_orbitCtrl, _introCtrl]),
                builder: (_, __) => CustomPaint(
                  painter: _OrbitPainter(
                    _orbitCtrl.value,
                    _introCtrl.value.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ),

          // ── Logo + wordmark ──
          Positioned(
            top: size.height * 0.28,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _introCtrl,
              builder: (_, __) => Opacity(
                opacity: _logoFade.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing logo circle
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFF1E6FD9), Color(0xFF0A3872)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E6FD9).withOpacity(0.55),
                              blurRadius: 48,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/icons/clinix_logo.png',
                            width: 52,
                            height: 52,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      // CLINIX wordmark with gradient
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFF93C5FD)],
                        ).createShader(bounds),
                        child: const Text(
                          'CLINIX',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: _taglineFade.value,
                        child: const Text(
                          'Your Health, Our Priority',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF7BA7D4),
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Feature service cards ──
          Positioned(
            bottom: 72,
            left: 24,
            right: 24,
            child: AnimatedBuilder(
              animation: _featuresCtrl,
              builder: (_, __) => Opacity(
                opacity: _featuresCtrl.value,
                child: Transform.translate(
                  offset: Offset(0, _featureSlide.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _FeatureCard(
                            icon: Icons.video_call_rounded,
                            color: const Color(0xFF3B82F6),
                            label: 'Virtual\nConsults',
                          ),
                          const SizedBox(width: 10),
                          _FeatureCard(
                            icon: Icons.biotech_rounded,
                            color: const Color(0xFF10B981),
                            label: 'Lab\nTests',
                          ),
                          const SizedBox(width: 10),
                          _FeatureCard(
                            icon: Icons.medical_services_rounded,
                            color: const Color(0xFFF59E0B),
                            label: 'Home\nCare',
                          ),
                          const SizedBox(width: 10),
                          _FeatureCard(
                            icon: Icons.local_hospital_rounded,
                            color: const Color(0xFFEC4899),
                            label: 'In-Person\nVisits',
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _LoadingDots(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Background: dark navy with gradient blobs + subtle grid ─────────────────
class _BackgroundPainter extends CustomPainter {
  final double t;
  _BackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF07111F));

    // Top-right blue blob
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.14),
      260 + 20 * t,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF1E3A8A).withOpacity(0.45 + 0.12 * t),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.78, size.height * 0.14),
          radius: 280,
        )),
    );

    // Bottom-left teal blob
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.84),
      200 + 15 * (1 - t),
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF0E7490).withOpacity(0.30 + 0.10 * t),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.18, size.height * 0.84),
          radius: 220,
        )),
    );

    // Subtle grid
    final grid = Paint()
      ..color = const Color(0xFF1E3A5F).withOpacity(0.18)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Bottom vignette fade
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0xFF07111F).withOpacity(0.85)],
          stops: const [0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.t != t;
}

// ── Orbiting dots around a medical cross ─────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  final double orbitT;
  final double introT;
  _OrbitPainter(this.orbitT, this.introT);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final alpha = (introT * 255).round().clamp(0, 255);

    // Outer orbit ring
    canvas.drawCircle(
      Offset(cx, cy),
      112,
      Paint()
        ..color = const Color(0xFF1E6FD9).withOpacity(0.12 * introT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Inner orbit ring
    canvas.drawCircle(
      Offset(cx, cy),
      76,
      Paint()
        ..color = const Color(0xFF1E6FD9).withOpacity(0.08 * introT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 4 outer orbiting dots (blue)
    for (int i = 0; i < 4; i++) {
      final angle = orbitT * 2 * math.pi + (i * math.pi / 2);
      canvas.drawCircle(
        Offset(cx + 112 * math.cos(angle), cy + 112 * math.sin(angle)),
        4,
        Paint()..color = Color.fromARGB((alpha * 0.6).round(), 30, 111, 217),
      );
    }

    // 3 inner counter-rotating dots (teal)
    for (int i = 0; i < 3; i++) {
      final angle = -orbitT * 2 * math.pi + (i * 2 * math.pi / 3);
      canvas.drawCircle(
        Offset(cx + 76 * math.cos(angle), cy + 76 * math.sin(angle)),
        3,
        Paint()..color = Color.fromARGB((alpha * 0.55).round(), 16, 185, 129),
      );
    }

    // Medical cross
    final crossPaint = Paint()
      ..color = Color.fromARGB(alpha, 30, 111, 217)
      ..style = PaintingStyle.fill;
    const cSize = 32.0;
    const cThick = 10.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: cSize, height: cThick),
        const Radius.circular(3),
      ),
      crossPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: cThick, height: cSize),
        const Radius.circular(3),
      ),
      crossPaint,
    );

    // Cross glow
    canvas.drawCircle(
      Offset(cx, cy),
      50,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromARGB((alpha * 0.14).round(), 30, 111, 217),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 50)),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) =>
      old.orbitT != orbitT || old.introT != introT;
}

// ── Individual service card ───────────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _FeatureCard({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E33),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7BA7D4),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouncing loading dots ─────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final phase = ((_ctrl.value - i * 0.22) % 1.0).clamp(0.0, 1.0);
          final pulse = math.sin(phase * math.pi).clamp(0.0, 1.0);
          final scale = 0.55 + 0.45 * pulse;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 7 * scale,
            height: 7 * scale,
            decoration: BoxDecoration(
              color: Color.lerp(
                const Color(0xFF1E4070),
                const Color(0xFF3B82F6),
                pulse,
              ),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
