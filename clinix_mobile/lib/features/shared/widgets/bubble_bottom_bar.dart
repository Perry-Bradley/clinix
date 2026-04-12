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
    this.backgroundColor = AppColors.splashSlate900,
    this.selectedColor = AppColors.sky500,
    this.unselectedColor = const Color(0x99FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final int idx = entry.key;
          final item = entry.value;
          final bool isSelected = idx == currentIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(idx),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: isSelected ? 10 : 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected ? Colors.white : unselectedColor,
                      size: isSelected ? 22 : 21,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Inter',
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class BubbleNavItem {
  final IconData icon;
  final String label;

  BubbleNavItem({required this.icon, required this.label});
}
