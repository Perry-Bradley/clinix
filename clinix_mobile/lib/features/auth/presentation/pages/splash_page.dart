import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:clinix_mobile/core/services/auth_service.dart';
import 'package:clinix_mobile/core/theme/app_colors.dart';
import 'package:clinix_mobile/core/theme/app_text_styles.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _blurAnimation = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _mainController.forward().then((_) async {
      const storage = FlutterSecureStorage();
      final onboardingSeen = await storage.read(key: 'onboarding_seen');
      final token = await AuthService.getAccessToken();
      final userType = await AuthService.getUserType();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        // Show onboarding on first launch (before login)
        if (onboardingSeen != 'true') {
          context.go('/onboarding');
          return;
        }

        if (token == null) {
          context.go('/login');
          return;
        }

        if (userType == 'unassigned') {
          context.go('/role-selection');
        } else if (userType == 'provider') {
          context.go('/provider/home');
        } else {
          context.go('/patient/home');
        }
      });
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E293B), // Slate 800
                  Color(0xFF0F172A),
                ],
              ),
            ),
          ),
          
          // Animated Content
          Center(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Container with Glassmorphism
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.sky500.withOpacity(0.3),
                                blurRadius: 40,
                                spreadRadius: -10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.spa_rounded, // Premium health/wellness icon
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // App Name
                        const Text(
                          'CLINIX',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Tagline
                        Text(
                          'Pioneering Modern Healthcare',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: AppColors.sky200.withOpacity(0.8),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom Loading Indicator
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sky400),
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
