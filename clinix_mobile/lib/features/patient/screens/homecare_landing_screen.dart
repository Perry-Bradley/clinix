import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class HomeCareLandingScreen extends StatelessWidget {
  const HomeCareLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.splashSlate900,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: w * 0.04),
              Text(
                'HomeCare',
                style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.065, fontWeight: FontWeight.w800, color: AppColors.splashSlate900),
              ),
              SizedBox(height: w * 0.02),
              Text(
                'We bring healthcare to your doorstep.\nWhat do you need?',
                style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.036, color: AppColors.grey500, height: 1.5),
              ),
              SizedBox(height: w * 0.1),
              _ServiceOption(
                icon: Icons.science_rounded,
                title: 'Request Lab Test',
                subtitle: 'Book a test and a nurse comes to collect your sample at home',
                onTap: () => context.push('/homecare/lab-tests'),
              ),
              SizedBox(height: w * 0.04),
              _ServiceOption(
                icon: Icons.medical_services_rounded,
                title: 'Home Treatment',
                subtitle: 'Medication administration, wound care, injections, and more',
                onTap: () => context.push('/homecare/treatments'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ServiceOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(w * 0.05),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(w * 0.035),
              decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: AppColors.splashSlate900, size: w * 0.065),
            ),
            SizedBox(width: w * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                  SizedBox(height: w * 0.01),
                  Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: AppColors.grey500, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: w * 0.04, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }
}
