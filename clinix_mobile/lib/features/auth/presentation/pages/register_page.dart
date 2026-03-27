import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _userType = 'patient';
  bool _isLoading = false;
  bool _obscurePass = true;

  void _register() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      context.push('/register/otp?phone=${_phoneCtrl.text}');
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _phoneCtrl.dispose(); _passCtrl.dispose();
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
                    Text('Create Account 🎉', style: AppTextStyles.displayLarge.copyWith(fontSize: 26)),
                    const SizedBox(height: 8),
                    Text('Join thousands of Cameroonians using Clinix', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.sky200, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Form Card
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
                          // Account Type Selector
                          Text('I am a...', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _TypeChip(label: 'Patient', icon: '🧑‍⚕️', value: 'patient', selected: _userType == 'patient', onTap: () => setState(() => _userType = 'patient')),
                              const SizedBox(width: 12),
                              _TypeChip(label: 'Doctor', icon: '👨‍⚕️', value: 'provider', selected: _userType == 'provider', onTap: () => setState(() => _userType = 'provider')),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: _buildField('First Name', _firstNameCtrl, Icons.person_outline)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildField('Last Name', _lastNameCtrl, null)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Phone Number'),
                          const SizedBox(height: 8),
                          AuthTextField(
                            controller: _phoneCtrl,
                            hint: '+237 6XX XXX XXX',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
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

  Widget _buildField(String label, TextEditingController ctrl, IconData? icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        AuthTextField(
          controller: ctrl,
          hint: label,
          prefixIcon: icon,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label, icon, value;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.icon, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.sky500 : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.sky500 : AppColors.grey200, width: 1.5),
            boxShadow: selected ? [BoxShadow(color: AppColors.sky500.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(label, style: AppTextStyles.headlineSmall.copyWith(fontSize: 13, color: selected ? AppColors.white : AppColors.grey700)),
            ],
          ),
        ),
      ),
    );
  }
}
