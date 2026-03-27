import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AppointmentDetailPage extends StatelessWidget {
  final String appointmentId;
  const AppointmentDetailPage({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.darkBlue900,
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.white, size: 16),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.sky500, AppColors.sky300]),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: const Icon(Icons.person_rounded, color: AppColors.white, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Dr. Marie Nkomo', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text('Cardiologist', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Status Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.sky100,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.sky300),
                  ),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.sky500, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text('Confirmed', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.sky600)),
                      const Spacer(),
                      Text('Video Consult', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Info Cards
                _InfoRow(icon: Icons.calendar_today_rounded, label: 'Date', value: 'April 12, 2026'),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.access_time_rounded, label: 'Time', value: '10:00 AM - 10:30 AM'),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.attach_money_rounded, label: 'Fee', value: 'XAF 15,000'),
                const SizedBox(height: 28),
                // Notes
                Text('Reason for Visit', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
                  child: Text('Routine cardiac checkup and ECG review.', style: AppTextStyles.bodyLarge),
                ),
                const SizedBox(height: 28),
                // CTA Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.videocam_rounded, size: 18),
                        label: const Text('Join Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sky500,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.sky500, size: 20),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMedium),
          const Spacer(),
          Text(value, style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}
