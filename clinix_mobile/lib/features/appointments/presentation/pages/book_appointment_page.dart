import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class BookAppointmentPage extends StatefulWidget {
  final String providerId;
  const BookAppointmentPage({super.key, required this.providerId});

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  String _appointmentType = 'video';
  bool _isLoading = false;

  final List<String> _timeSlots = ['09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '14:00', '14:30', '15:00', '15:30'];

  void _confirm() async {
    if (_selectedTime == null) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Appointment booked successfully!'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.go('/patient/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.darkBlue900,
            expandedHeight: 180,
            pinned: true,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.white, size: 16),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                child: Row(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.sky500, AppColors.sky300]), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                      child: const Icon(Icons.person_rounded, color: AppColors.white, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Book Appointment', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                        const SizedBox(height: 4),
                        Text('Dr. Marie Nkomo', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white, fontSize: 18)),
                        Text('Cardiologist', style: AppTextStyles.caption.copyWith(color: AppColors.sky300)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Appointment Type
                Text('Appointment Type', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _TypeButton(label: '📹 Video Call', value: 'video', selected: _appointmentType == 'video', onTap: () => setState(() => _appointmentType = 'video')),
                    const SizedBox(width: 12),
                    _TypeButton(label: '🏥 In-Person', value: 'in_person', selected: _appointmentType == 'in_person', onTap: () => setState(() => _appointmentType = 'in_person')),
                  ],
                ),
                const SizedBox(height: 24),

                // Date Picker
                Text('Select Date', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 88,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    itemBuilder: (ctx, i) {
                      final date = DateTime.now().add(Duration(days: i + 1));
                      final isSelected = _selectedDate.day == date.day && _selectedDate.month == date.month;
                      return GestureDetector(
                        onTap: () => setState(() { _selectedDate = date; _selectedTime = null; }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          width: 62,
                          decoration: BoxDecoration(
                            gradient: isSelected ? const LinearGradient(colors: [AppColors.sky600, AppColors.sky400]) : null,
                            color: isSelected ? null : AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? AppColors.sky500 : AppColors.grey200),
                            boxShadow: isSelected ? [BoxShadow(color: AppColors.sky500.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][date.weekday - 1],
                                style: AppTextStyles.caption.copyWith(color: isSelected ? AppColors.white : AppColors.grey400, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${date.day}',
                                style: AppTextStyles.headlineMedium.copyWith(fontSize: 20, color: isSelected ? AppColors.white : AppColors.darkBlue800),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Time Slots
                Text('Available Times', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _timeSlots.map((t) {
                    final isSelected = _selectedTime == t;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTime = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSelected ? const LinearGradient(colors: [AppColors.sky600, AppColors.sky400]) : null,
                          color: isSelected ? null : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? AppColors.sky500 : AppColors.grey200),
                          boxShadow: isSelected ? [BoxShadow(color: AppColors.sky500.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
                        ),
                        child: Text(t, style: AppTextStyles.headlineSmall.copyWith(fontSize: 13, color: isSelected ? AppColors.white : AppColors.grey700)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedTime == null || _isLoading ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sky500,
                      disabledBackgroundColor: AppColors.grey200,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(AppColors.white)))
                      : Text('Confirm Booking • XAF 15,000', style: AppTextStyles.labelLarge.copyWith(fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: selected ? const LinearGradient(colors: [AppColors.sky600, AppColors.sky400]) : null,
            color: selected ? null : AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.sky500 : AppColors.grey200),
            boxShadow: selected ? [BoxShadow(color: AppColors.sky500.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
          ),
          child: Center(
            child: Text(label, style: AppTextStyles.headlineSmall.copyWith(fontSize: 13, color: selected ? AppColors.white : AppColors.grey700)),
          ),
        ),
      ),
    );
  }
}
