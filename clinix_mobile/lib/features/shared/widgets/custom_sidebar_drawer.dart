import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class CustomSidebarDrawer extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final bool isProvider;

  const CustomSidebarDrawer({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.isProvider = false,
  });

  @override
  State<CustomSidebarDrawer> createState() => _CustomSidebarDrawerState();
}

class _CustomSidebarDrawerState extends State<CustomSidebarDrawer> {
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await AuthService.getUserName();
    if (mounted && name != null) setState(() => _userName = name);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final roleLabel = widget.isProvider ? 'Healthcare Provider' : 'Patient';
    final initial = _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U';

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(w * 0.06, w * 0.08, w * 0.06, w * 0.06),
              child: Row(
                children: [
                  Container(
                    width: w * 0.13,
                    height: w * 0.13,
                    decoration: BoxDecoration(
                      color: AppColors.splashSlate900.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(initial, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.05, fontWeight: FontWeight.w700, color: AppColors.splashSlate900))),
                  ),
                  SizedBox(width: w * 0.035),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_userName, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.042, fontWeight: FontWeight.w700, color: AppColors.splashSlate900), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: w * 0.005),
                        Text(roleLabel, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: AppColors.grey500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: AppColors.grey100),

            // Menu items
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SideItem(icon: Icons.home_rounded, label: 'Home', selected: widget.currentIndex == 0, onTap: () { Navigator.pop(context); widget.onTabSelected(0); }),
                    _SideItem(
                      icon: widget.isProvider ? Icons.calendar_month_rounded : Icons.search_rounded,
                      label: widget.isProvider ? 'Schedule' : 'Find Doctors',
                      selected: widget.currentIndex == 1,
                      onTap: () { Navigator.pop(context); widget.onTabSelected(1); },
                    ),
                    _SideItem(icon: Icons.spa_rounded, label: 'Clinix AI', onTap: () { Navigator.pop(context); context.push('/ai-consult'); }),
                    _SideItem(icon: Icons.event_note_rounded, label: 'Appointments', onTap: () { Navigator.pop(context); context.push(widget.isProvider ? '/provider/appointments' : '/patient/appointments'); }),
                    _SideItem(icon: Icons.chat_rounded, label: 'Messages', onTap: () { Navigator.pop(context); context.push(widget.isProvider ? '/provider/messages' : '/patient/messages'); }),
                    if (!widget.isProvider)
                      _SideItem(icon: Icons.science_rounded, label: 'Lab Tests', onTap: () { Navigator.pop(context); context.push('/homecare/lab-tests'); }),
                    _SideItem(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      selected: widget.currentIndex == (widget.isProvider ? 3 : 4),
                      onTap: () { Navigator.pop(context); widget.onTabSelected(widget.isProvider ? 3 : 4); },
                    ),
                  ],
                ),
              ),
            ),

            // Sign out
            Padding(
              padding: EdgeInsets.fromLTRB(w * 0.04, 0, w * 0.04, w * 0.06),
              child: _SideItem(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                isDestructive: true,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sign Out', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await AuthService.logoutAndClear(context);
                    if (context.mounted) context.go('/login');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SideItem({required this.icon, required this.label, required this.onTap, this.selected = false, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final iconColor = isDestructive ? AppColors.error : (selected ? AppColors.darkBlue500 : AppColors.grey400);
    final textColor = isDestructive ? AppColors.error : (selected ? AppColors.darkBlue800 : AppColors.grey700);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.035),
        margin: EdgeInsets.only(bottom: w * 0.01),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkBlue500.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: w * 0.055, color: iconColor),
            SizedBox(width: w * 0.035),
            Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: textColor)),
          ],
        ),
      ),
    );
  }
}
