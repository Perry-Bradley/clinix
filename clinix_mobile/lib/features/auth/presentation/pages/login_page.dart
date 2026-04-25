import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/notification_service.dart';
import '../widgets/auth_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String? _errorMessage;

  void _login() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final data = await AuthService.login(
        identifier: _idCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await NotificationService.registerToken();
      if (mounted) {
        final userType = data['user_type'] ?? 'unassigned';
        if (userType == 'unassigned') {
          context.go('/role-selection');
        } else {
          context.go(userType == 'provider' ? '/provider/home' : '/patient/home');
        }
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) msg = data['error']?.toString();
      if (data is String) msg = data.length > 100 ? 'Server error. Please try again later.' : data;
      setState(() => _errorMessage = msg ?? 'Invalid credentials. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _googleLogin() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final data = await AuthService.signInWithGoogle();
      if (data != null) {
        await NotificationService.registerToken();
      }
      if (mounted && data != null) {
        final userType = data['user_type'] ?? 'unassigned';
        if (userType == 'unassigned') {
          context.go('/role-selection');
        } else {
          context.go(userType == 'provider' ? '/provider/home' : '/patient/home');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Google Sign-In failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle sky-blue glow accent in the corner — single light touch.
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.sky100, Colors.white.withOpacity(0)],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo badge — Clinix mark on a sky-blue badge (matches active nav)
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.darkBlue500,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkBlue500.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/icons/clinix_logo.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Welcome back',
                      style: AppTextStyles.displayLarge.copyWith(
                        fontSize: 30,
                        color: AppColors.darkBlue900,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to continue your health journey.',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.grey500,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Identifier ──
                    Text('Email or phone number',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.darkBlue900,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 8),
                    AuthTextField(
                      controller: _idCtrl,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.text,
                      prefixIcon: Icons.alternate_email_rounded,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter email or phone number' : null,
                    ),
                    const SizedBox(height: 18),

                    // ── Password ──
                    Text('Password',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.darkBlue900,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 8),
                    AuthTextField(
                      controller: _passCtrl,
                      hint: '••••••••',
                      obscureText: _obscurePass,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.grey400,
                          size: 20,
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.darkBlue500,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFB91C1C), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTextStyles.caption.copyWith(
                                  color: const Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // ── Sign in button (sky-blue, matches active nav) ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkBlue500,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.darkBlue500.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Sign in',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Divider ──
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.grey200)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.grey400,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: AppColors.grey200)),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // ── Google ──
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _googleLogin,
                        icon: SizedBox(
                          width: 18, height: 18,
                          child: Image.network(
                            "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png",
                            height: 18,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.g_mobiledata_rounded,
                                    size: 22, color: AppColors.darkBlue800),
                          ),
                        ),
                        label: Text(
                          'Continue with Google',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBlue900,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.grey200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?",
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.grey500,
                              fontSize: 14,
                            )),
                        TextButton(
                          onPressed: () => context.push('/register'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Sign up',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.darkBlue500,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
