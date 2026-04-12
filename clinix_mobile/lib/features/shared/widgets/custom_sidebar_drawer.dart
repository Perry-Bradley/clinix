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
    final roleLabel = widget.isProvider ? 'Healthcare provider' : 'Verified patient';
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.sky100,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.sky200, width: 1.5),
                          ),
                          child: const Center(child: Icon(Icons.person_rounded, color: AppColors.sky600, size: 32)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkBlue900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                roleLabel,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    _DrawerItem(
                      icon: Icons.home_rounded,
                      label: 'Dashboard',
                      isSelected: widget.currentIndex == 0,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTabSelected(0);
                      },
                    ),
                    _DrawerItem(
                      icon: widget.isProvider ? Icons.calendar_month_rounded : Icons.medical_services_rounded,
                      label: widget.isProvider ? 'Schedule' : 'Top Doctors',
                      isSelected: widget.currentIndex == 1,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTabSelected(1);
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.psychology_rounded,
                      label: 'Clinix AI',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/ai-consult');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.event_note_rounded,
                      label: 'Appointments',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(widget.isProvider ? '/provider/appointments' : '/patient/appointments');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Messages',
                      isSelected: false,
                      onTap: () {
                        Navigator.pop(context);
                        context.push(widget.isProvider ? '/provider/messages' : '/patient/messages');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.person_rounded,
                      label: 'My Profile',
                      isSelected: widget.currentIndex == (widget.isProvider ? 3 : 4),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onTabSelected(widget.isProvider ? 3 : 4);
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                isSelected: false,
                color: AppColors.error,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Logout', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await AuthService.logout();
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.sky600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? activeColor : (color ?? AppColors.grey500),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? activeColor : (color ?? AppColors.darkBlue900.withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
