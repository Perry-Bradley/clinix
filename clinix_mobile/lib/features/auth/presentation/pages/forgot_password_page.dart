import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_button.dart';

/// Two-step password reset: enter the account email, then the emailed
/// 6-digit code together with the new password.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscurePass = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _dioMessage(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
    }
    return fallback;
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await AuthService.requestPasswordReset(email: _emailCtrl.text.trim());
      if (mounted) {
        setState(() => _codeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset code sent — check your email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            _dioMessage(e, 'Could not send the reset code. Try again.'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await AuthService.confirmPasswordReset(
        email: _emailCtrl.text.trim(),
        otp: _otpCtrl.text.trim(),
        newPassword: _passCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated. Sign in with your new password.'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            _dioMessage(e, 'Could not reset the password. Check the code and try again.'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.white, size: 18),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Icon(Icons.lock_reset_rounded, color: AppColors.white, size: 48),
                    const SizedBox(height: 16),
                    Text('Reset Password', style: AppTextStyles.displayLarge.copyWith(fontSize: 26)),
                    const SizedBox(height: 8),
                    Text(
                      _codeSent
                          ? 'Enter the 6-digit code we emailed you and choose a new password.'
                          : 'Enter your account email and we\'ll send you a reset code.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTextField(
                            controller: _emailCtrl,
                            hint: 'you@example.com',
                            prefixIcon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_codeSent,
                            validator: (v) => v == null || !v.contains('@')
                                ? 'Enter a valid email'
                                : null,
                          ),
                          if (_codeSent) ...[
                            const SizedBox(height: 16),
                            AuthTextField(
                              controller: _otpCtrl,
                              hint: '6-digit code',
                              prefixIcon: Icons.pin_rounded,
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.trim().length != 6
                                  ? 'Enter the 6-digit code'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            AuthTextField(
                              controller: _passCtrl,
                              hint: 'Min 6 characters',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscurePass,
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                icon: Icon(
                                  _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.grey400, size: 20,
                                ),
                              ),
                              validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                            ),
                            const SizedBox(height: 16),
                            AuthTextField(
                              controller: _confirmCtrl,
                              hint: 'Repeat the password',
                              prefixIcon: Icons.lock_outline_rounded,
                              obscureText: _obscurePass,
                              validator: (v) => v != _passCtrl.text ? 'Passwords don\'t match' : null,
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          GradientButton(
                            text: _codeSent ? 'Reset Password' : 'Send Reset Code',
                            isLoading: _isLoading,
                            onPressed: _codeSent ? _resetPassword : _sendCode,
                          ),
                          if (_codeSent) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton(
                                onPressed: _isLoading ? null : _sendCode,
                                child: Text(
                                  'Resend code',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.sky500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
