import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Floating pill nav aligned with Clinix splash (slate) + sky accent.
class BubbleBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BubbleNavItem> items;
  final Color backgroundColor;
  final Color selectedColor;
  final Color unselectedColor;

  const BubbleBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor = Colors.white,
    this.selectedColor = AppColors.sky600,
    this.unselectedColor = const Color(0xFF94A3B8), // Slate 400
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final int idx = entry.key;
              final item = entry.value;
              final bool isSelected = idx == currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(idx),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? selectedColor.withOpacity(0.12) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.icon,
                          color: isSelected ? selectedColor : unselectedColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? selectedColor : unselectedColor,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
