import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Wraps a list-row [child] with a right-to-left swipe gesture that reveals a
/// red "Delete" hint and removes the row when fully swiped. The actual delete
/// (HTTP call or local-state hide) is wired through [onDelete] — return true
/// to confirm the dismissal, false to keep the row.
class SwipeToDeleteCard extends StatelessWidget {
  final Widget child;
  final Future<bool> Function() onDelete;
  final String dismissibleKey;
  final String? deletedSnack;
  final String? confirmTitle;
  final String? confirmBody;
  final String deleteLabel;

  const SwipeToDeleteCard({
    super.key,
    required this.child,
    required this.onDelete,
    required this.dismissibleKey,
    this.deletedSnack = 'Removed',
    this.confirmTitle,
    this.confirmBody,
    this.deleteLabel = 'Delete',
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('swipe-$dismissibleKey'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              deleteLabel,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        // Optional confirmation dialog (only shown if title/body supplied).
        if (confirmTitle != null) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(
                confirmTitle!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.darkBlue900,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              content: Text(
                confirmBody ?? 'This action cannot be undone.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: AppColors.darkBlue900,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep', style: TextStyle(color: AppColors.grey500, fontWeight: FontWeight.w700)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: Text(deleteLabel, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          );
          if (ok != true) return false;
        }

        final result = await onDelete();
        if (!result) return false;
        if (context.mounted && deletedSnack != null && deletedSnack!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(deletedSnack!), behavior: SnackBarBehavior.floating),
          );
        }
        return true;
      },
      child: child,
    );
  }
}
