import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/gradient_button.dart';

class OtpPage extends StatefulWidget {
  final String email;
  const OtpPage({super.key, required this.email});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with TickerProviderStateMixin {
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendTimer = 60;
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut));
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _foci[0].requestFocus());
  }

  void _startResendTimer() async {
    while (_resendTimer > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendTimer--);
    }
  }
 
  void _resendOtp() async {
    setState(() { _isLoading = true; _errorMessage = null; _resendTimer = 60; });
    _startResendTimer();
    try {
      await AuthService.sendEmailOtp(email: widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code resent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to resend code. Try again later.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verifyOtp() async {
    final otp = _ctrls.map((c) => c.text).join();
    if (otp.length < 6) {
      _shakeController.forward(from: 0);
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final data = await AuthService.verifyEmailOtp(email: widget.email, otp: otp);
      if (mounted) {
        final userType = data['user_type'] ?? 'patient';
        context.go(userType == 'provider' ? '/provider/home' : '/patient/home');
      }
    } on DioException catch (e) {
      _shakeController.forward(from: 0);
      final data = e.response?.data;
      String? msg;
      if (data is Map) msg = data['error']?.toString();
      if (data is String) msg = data.length > 100 ? 'Server error. Please try again later.' : data;
      setState(() => _errorMessage = msg ?? 'Invalid or expired code.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    for (final f in _foci) { f.dispose(); }
    _shakeController.dispose();
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
                    const SizedBox(height: 32),
                    const Text('📧', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text('Verify Your Email', style: AppTextStyles.displayLarge.copyWith(fontSize: 26)),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200, fontSize: 14),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit code to '),
                          TextSpan(text: widget.email, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  decoration: const BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (ctx, child) => Transform.translate(
                          offset: Offset(10 * (0.5 - _shakeAnimation.value).abs() * (_shakeAnimation.value > 0.5 ? 1 : -1), 0),
                          child: child,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (i) => _OtpBox(
                            controller: _ctrls[i],
                            focusNode: _foci[i],
                            onChanged: (val) {
                              if (val.isNotEmpty && i < 5) _foci[i + 1].requestFocus();
                              if (val.isEmpty && i > 0) _foci[i - 1].requestFocus();
                            },
                          )),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                      const SizedBox(height: 40),
                      GradientButton(text: 'Verify Code', isLoading: _isLoading, onPressed: _verifyOtp),
                      const SizedBox(height: 28),
                      if (_resendTimer > 0)
                        Text('Resend code in ${_resendTimer}s', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400))
                      else
                        TextButton(
                          onPressed: _isLoading ? null : _resendOtp,
                          child: Text('Resend Code', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontWeight: FontWeight.w600)),
                        ),
                    ],
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48, height: 58,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: AppTextStyles.headlineLarge.copyWith(fontSize: 22, color: AppColors.darkBlue800),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.grey200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.grey200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.sky500, width: 2.5)),
        ),
      ),
    );
  }
}
