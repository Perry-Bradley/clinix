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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.splashSlate900,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => AuthService.logout().then((_) => context.go('/login')),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Welcome to Clinix',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.splashSlate900,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us who you are so we can tailor your experience.',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey500),
              ),
              const SizedBox(height: 48),
              _RoleCard(
                title: 'Patient',
                subtitle: 'Looking for consultation and health advice',
                icon: Icons.person_outline_rounded,
                isSelected: _selectedRole == 'patient',
                onTap: () => _onRoleSelected('patient'),
                isLoading: _isLoading && _selectedRole == 'patient',
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: 'Healthcare Professional',
                subtitle: 'Registering as a doctor, nurse, or midwife',
                icon: Icons.medical_services_outlined,
                isSelected: _selectedRole == 'provider',
                onTap: () => _onRoleSelected('provider'),
                isLoading: _isLoading && _selectedRole == 'provider',
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
    final activeColor = AppColors.splashSlate900;
    
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.grey50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.grey200,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon, 
                color: isSelected ? Colors.white : AppColors.grey500, 
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.splashSlate900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.grey500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.splashSlate900),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isSelected ? activeColor : AppColors.grey400,
              ),
          ],
        ),
      ),
    );
  }
}
