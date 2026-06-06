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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animated gradient background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        AppColors.sky100.withOpacity(0.3),
                        Colors.white,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Floating medical icons for visual interest
          Positioned(
            top: 80,
            left: 40,
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _mainController.value * 20),
                  child: Opacity(
                    opacity: _fadeAnimation.value * 0.6,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 32,
                      color: AppColors.sky300,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 150,
            right: 50,
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_mainController.value * 15),
                  child: Opacity(
                    opacity: _fadeAnimation.value * 0.5,
                    child: Icon(
                      Icons.medical_services_rounded,
                      size: 28,
                      color: AppColors.sky200,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 200,
            left: 60,
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_mainController.value * 10),
                  child: Opacity(
                    opacity: _fadeAnimation.value * 0.4,
                    child: Icon(
                      Icons.local_hospital_rounded,
                      size: 36,
                      color: AppColors.sky100,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 280,
            right: 70,
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _mainController.value * 12),
                  child: Opacity(
                    opacity: _fadeAnimation.value * 0.5,
                    child: Icon(
                      Icons.health_and_safety_rounded,
                      size: 30,
                      color: AppColors.sky200,
                    ),
                  ),
                );
              },
            ),
          ),

          // Animated content
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
                        // Logo block with enhanced shadow
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.darkBlue500,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.darkBlue500.withOpacity(0.25),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/icons/clinix_logo.png',
                              width: 70,
                              height: 70,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // App Name with gradient effect
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              AppColors.darkBlue900,
                              AppColors.darkBlue500,
                              AppColors.sky600,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'CLINIX',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pioneering Modern Healthcare',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.grey500,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Loading steps indicator
                        _buildLoadingSteps(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom progress bar
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.grey200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.darkBlue500,
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading your healthcare experience...',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.grey400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSteps() {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final progress = _mainController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStepDot(0, progress, Icons.check_circle_rounded),
            _buildStepDot(1, progress, Icons.person_rounded),
            _buildStepDot(2, progress, Icons.home_rounded),
          ],
        );
      },
    );
  }

  Widget _buildStepDot(int index, double progress, IconData icon) {
    final isActive = progress >= (index + 1) / 3;
    final isCurrent = progress >= index / 3 && progress < (index + 1) / 3;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.sky500
                  : isCurrent
                      ? AppColors.sky200
                      : AppColors.grey200,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.sky500.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isActive ? icon : Icons.circle_rounded,
              size: 20,
              color: isActive || isCurrent ? Colors.white : AppColors.grey400,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 24 : 8,
            height: 3,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.sky500
                  : isCurrent
                      ? AppColors.sky300
                      : AppColors.grey200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
