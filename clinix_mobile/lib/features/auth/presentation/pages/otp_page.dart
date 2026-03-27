import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';

class OtpPage extends StatefulWidget {
  final String phone;
  const OtpPage({super.key, required this.phone});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with TickerProviderStateMixin {
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendTimer = 60;
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

  void _verifyOtp() async {
    final otp = _ctrls.map((c) => c.text).join();
    if (otp.length < 6) {
      _shakeController.forward(from: 0);
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      context.go('/patient/home');
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
                    const Text('📱', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text('Verify Your Number', style: AppTextStyles.displayLarge.copyWith(fontSize: 26)),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200, fontSize: 14),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit code to '),
                          TextSpan(text: widget.phone, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
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
                      const SizedBox(height: 40),
                      GradientButton(text: 'Verify Code', isLoading: _isLoading, onPressed: _verifyOtp),
                      const SizedBox(height: 28),
                      if (_resendTimer > 0)
                        Text('Resend code in ${_resendTimer}s', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400))
                      else
                        TextButton(
                          onPressed: () { setState(() => _resendTimer = 60); _startResendTimer(); },
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
      width: 48,
      height: 58,
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
