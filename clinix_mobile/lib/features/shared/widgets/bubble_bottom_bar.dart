import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BubbleBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BubbleNavItem> items;

  const BubbleBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.02, vertical: w * 0.012),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final sel = idx == currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(idx),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(w * 0.02),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.darkBlue500.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          color: sel ? AppColors.darkBlue500 : AppColors.grey400,
                          size: w * 0.058,
                        ),
                      ),
                      SizedBox(height: w * 0.006),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: sel ? AppColors.darkBlue500 : AppColors.grey400,
                          fontSize: w * 0.027,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class BubbleNavItem {
  final IconData icon;
  final String label;
  BubbleNavItem({required this.icon, required this.label});
}
