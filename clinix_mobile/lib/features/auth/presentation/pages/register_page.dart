import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/auth_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  String? _errorMessage;

  void _register() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      await AuthService.register(
        fullName: _fullNameCtrl.text.trim(),
        identifier: _idCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) {
        // After registration, user is unassigned. 
        // We login automatically or force them to login page. 
        // For better UX, let's login automatically if backend returned tokens, 
        // but our basic register doesn't return tokens in this implementation.
        // So we redirect to login with a success message.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created! Please sign in.')),
        );
        context.go('/login');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) msg = data.values.expand((element) => element is List ? element : [element]).join('\n');
      setState(() => _errorMessage = msg ?? 'Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _googleRegister() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final data = await AuthService.signInWithGoogle();
      if (mounted && data != null) {
        final userType = data['user_type'] ?? 'unassigned';
        if (userType == 'unassigned') {
          context.go('/role-selection');
        } else {
          context.go(userType == 'provider' ? '/provider/home' : '/patient/home');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Google Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
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
            // Subtle sky-blue glow accent
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.grey50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey200),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.darkBlue900, size: 16),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Logo badge
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
                    const SizedBox(height: 24),

                    Text(
                      'Create your account',
                      style: AppTextStyles.displayLarge.copyWith(
                        fontSize: 28,
                        color: AppColors.darkBlue900,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join thousands of Cameroonians using Clinix.',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.grey500,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Full name ──
                    _buildLabel('Full name'),
                    const SizedBox(height: 8),
                    AuthTextField(
                      controller: _fullNameCtrl,
                      hint: 'Enter your full name',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 18),

                    // ── Identifier ──
                    _buildLabel('Email or phone number'),
                    const SizedBox(height: 8),
                    AuthTextField(
                      controller: _idCtrl,
                      hint: 'you@example.com',
                      keyboardType: TextInputType.text,
                      prefixIcon: Icons.alternate_email_rounded,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 18),

                    // ── Password ──
                    _buildLabel('Password'),
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

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
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

                    const SizedBox(height: 24),

                    // ── Create account button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
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
                                'Create account',
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
                        onPressed: _isLoading ? null : _googleRegister,
                        icon: SizedBox(
                          width: 18, height: 18,
                          child: Image.network(
                            "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png",
                            height: 18,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.g_mobiledata_rounded,
                                    size: 22, color: AppColors.darkBlue500),
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
                        Text(
                          'Already have an account?',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.grey500,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Sign in',
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

  Widget _buildLabel(String text) => Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.darkBlue900,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      );
}
