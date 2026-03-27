import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PatientBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const PatientBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.darkBlue900.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
        border: const Border(top: BorderSide(color: AppColors.grey200, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.search_rounded, label: 'Doctors', index: 1, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.calendar_month_rounded, label: 'Appointments', index: 2, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', index: 3, current: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.sky500.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? AppColors.sky500 : AppColors.grey400, size: 24),
            const SizedBox(height: 3),
            Text(label, style: AppTextStyles.caption.copyWith(color: isActive ? AppColors.sky500 : AppColors.grey400, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
