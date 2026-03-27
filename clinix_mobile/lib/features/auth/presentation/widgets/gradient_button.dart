import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;

  const GradientButton({
    super.key,
    required this.text,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isLoading ? null : const LinearGradient(colors: [AppColors.sky600, AppColors.sky400], begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: isLoading ? AppColors.grey200 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading ? [] : [BoxShadow(color: AppColors.sky500.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.grey400)))
            : Text(text, style: AppTextStyles.labelLarge.copyWith(fontSize: 16, letterSpacing: 0.3)),
        ),
      ),
    );
  }
}
