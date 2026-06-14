import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// "Liquid glass" bottom navigation — a translucent, blurred, rounded panel
/// with a soft pill highlight on the active tab (Telegram-style aesthetic).
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            // Frosted, semi-transparent panel.
            color: Colors.white.withOpacity(0.80),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.65), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: List.generate(items.length, (idx) {
                  final item = items[idx];
                  final sel = idx == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.darkBlue500.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sel ? item.activeIcon : item.icon,
                              color: sel ? AppColors.darkBlue500 : AppColors.grey400,
                              size: 23,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                height: 1.0,
                                color: sel ? AppColors.darkBlue500 : AppColors.grey400,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BubbleNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  BubbleNavItem({required this.icon, IconData? activeIcon, required this.label})
      : activeIcon = activeIcon ?? icon;
}
