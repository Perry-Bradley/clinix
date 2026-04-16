import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('About Clinix', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: AppColors.sky100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_hospital_rounded, color: AppColors.sky500, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Clinix', style: AppTextStyles.displayLarge.copyWith(fontSize: 28, color: AppColors.darkBlue900)),
            const SizedBox(height: 4),
            Text('v1.0.0', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Clinix is a comprehensive mobile healthcare platform built for Cameroon. '
                'It connects patients with verified healthcare providers for virtual and in-person consultations, '
                'powered by AI-assisted symptom triage and integrated mobile money payments.\n\n'
                'Our mission is to make quality healthcare accessible to everyone, '
                'regardless of location.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey700, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _AboutItem(icon: Icons.psychology_rounded, title: 'AI-Powered Triage', subtitle: 'Smart symptom analysis with Clinix AI'),
            _AboutItem(icon: Icons.video_call_rounded, title: 'Virtual Consultations', subtitle: 'Video calls with verified doctors'),
            _AboutItem(icon: Icons.phone_android_rounded, title: 'Mobile Money', subtitle: 'Pay with MTN MoMo or Orange Money'),
            _AboutItem(icon: Icons.monitor_heart_rounded, title: 'Health Tracking', subtitle: 'Heart rate, steps, and vitals monitoring'),
            _AboutItem(icon: Icons.verified_rounded, title: 'Verified Providers', subtitle: 'All doctors are KYC-verified'),
            const SizedBox(height: 32),
            Text('Built with care in Cameroon', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _AboutItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppColors.sky100, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.sky500, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
