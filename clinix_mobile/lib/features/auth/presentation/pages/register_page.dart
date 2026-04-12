import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_button.dart';

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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Create Account', style: AppTextStyles.displayLarge.copyWith(fontSize: 26)),
                    const SizedBox(height: 8),
                    Text('Join thousands of Cameroonians using Clinix', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.sky200, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
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
                          _buildLabel('Full Name'),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _fullNameCtrl,
                            hint: 'Enter your full name',
                            prefixIcon: Icons.person_outline,
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Email or Phone Number'),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _idCtrl,
                            hint: 'you@example.com or phone',
                            keyboardType: TextInputType.text,
                            prefixIcon: Icons.account_circle_outlined,
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Password'),
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
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                              child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                            ),
                          ],
                          const SizedBox(height: 28),
                          GradientButton(text: 'Create Account', isLoading: _isLoading, onPressed: _register),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Already have an account?', style: AppTextStyles.bodyMedium),
                              TextButton(
                                onPressed: () => context.go('/login'),
                                child: Text('Sign In', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _googleRegister,
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
                          const SizedBox(height: 40),
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

  Widget _buildLabel(String text) => Text(text, style: AppTextStyles.headlineSmall.copyWith(fontSize: 14));
}
