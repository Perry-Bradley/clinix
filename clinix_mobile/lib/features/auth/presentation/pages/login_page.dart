import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/notification_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_button.dart';

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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_hospital_rounded, color: AppColors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text('Clinix', style: TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.white)),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text('Welcome back', style: AppTextStyles.displayLarge.copyWith(fontSize: 30)),
                    const SizedBox(height: 8),
                    Text('Sign in to continue your health journey', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.sky200)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Form Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: const BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email or Phone Number', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _idCtrl,
                            hint: 'Email or phone number',
                            keyboardType: TextInputType.text,
                            prefixIcon: Icons.account_circle_outlined,
                            validator: (v) => v == null || v.isEmpty ? 'Enter email or phone number' : null,
                          ),
                          const SizedBox(height: 20),
                          Text('Password', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _passCtrl,
                            hint: '••••••••',
                            obscureText: _obscurePass,
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                              icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.grey400, size: 20),
                            ),
                            validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: Text('Forgot Password?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500)),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          GradientButton(text: 'Sign In', isLoading: _isLoading, onPressed: _login),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.grey200)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('or', style: AppTextStyles.caption.copyWith(fontSize: 13)),
                              ),
                              const Expanded(child: Divider(color: AppColors.grey200)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _googleLogin,
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: SizedBox(
                                  width: 18, height: 18,
                                  child: Image.network(
                                    "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png",
                                    height: 18,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_circle_outlined, size: 18, color: AppColors.sky600),
                                  ),
                                ),
                              ),
                              label: Text('Continue with Google', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkBlue900)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.grey200),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Don't have an account?", style: AppTextStyles.bodyMedium),
                              TextButton(
                                onPressed: () => context.push('/register'),
                                child: Text('Sign Up', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontWeight: FontWeight.w700)),
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
      ),
    );
  }
}
