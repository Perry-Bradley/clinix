import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _isLoading = false;
  String? _selectedRole;

  Future<void> _onRoleSelected(String role) async {
    setState(() {
      _isLoading = true;
      _selectedRole = role;
    });

    try {
      await AuthService.selectRole(userType: role);
      if (mounted) {
        if (role == 'patient') {
          context.go('/patient/home');
        } else {
          context.go('/register/provider-enrollment');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'Welcome to Clinix',
                style: AppTextStyles.displayLarge.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 12),
              Text(
                'Tell us who you are so we can tailor your experience.',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.sky200),
              ),
              const SizedBox(height: 60),
              _RoleCard(
                title: 'I am a Patient',
                subtitle: 'Looking for consultation and health advice',
                icon: Icons.person_search_rounded,
                isSelected: _selectedRole == 'patient',
                onTap: () => _onRoleSelected('patient'),
                isLoading: _isLoading && _selectedRole == 'patient',
              ),
              const SizedBox(height: 24),
              _RoleCard(
                title: 'I am a Healthcare Professional',
                subtitle: 'Registering as a doctor, nurse, or midwife',
                icon: Icons.medical_services_rounded,
                isSelected: _selectedRole == 'provider',
                onTap: () => _onRoleSelected('provider'),
                isLoading: _isLoading && _selectedRole == 'provider',
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () => AuthService.logout().then((_) => context.go('/login')),
                  child: Text(
                    'Cancel & Logout',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLoading;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sky600.withOpacity(0.2) : AppColors.darkBlue700,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.sky500 : Colors.white12,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.sky500.withOpacity(0.2), blurRadius: 20)]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.sky500 : AppColors.darkBlue900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.headlineSmall.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: isSelected ? AppColors.sky300 : AppColors.grey500,
              ),
          ],
        ),
      ),
    );
  }
}
