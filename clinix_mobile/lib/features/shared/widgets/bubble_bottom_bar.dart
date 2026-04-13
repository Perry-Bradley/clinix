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
    return SafeArea(
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
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
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  padding: EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: isSelected ? 11 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected ? Colors.white : unselectedColor,
                        size: 19,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: isSelected ? Colors.white : unselectedColor,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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
