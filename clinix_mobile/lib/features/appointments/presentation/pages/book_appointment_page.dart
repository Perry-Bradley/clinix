import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/appointment_service.dart';
import '../../../../core/constants/api_constants.dart';

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
  bool _isFetchingSlots = false;
  String _consultationFee = '15,000';

  List<String> _timeSlots = [];
  Map<String, dynamic>? _providerData;
  List<dynamic> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadProviderInfo();
    _loadSlots();
  }

  Future<void> _loadProviderInfo() async {
    try {
      final response = await Dio().get('${ApiConstants.baseUrl}${ApiConstants.providers}${widget.providerId}/');
      if (mounted && response.data is Map) {
        setState(() {
          _providerData = Map<String, dynamic>.from(response.data as Map);
          _schedules = (_providerData!['schedules'] as List?) ?? [];
          final fee = _providerData!['consultation_fee']?.toString() ?? '15000';
          final parsed = double.tryParse(fee) ?? 15000;
          _consultationFee = parsed.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSlots() async {
    setState(() => _isFetchingSlots = true);
    try {
      final slots = await AppointmentService.getAvailableSlots(widget.providerId, _selectedDate);
      setState(() {
        _timeSlots = slots.map((s) => s.split('T')[1].substring(0, 5)).toList();
        _isFetchingSlots = false;
      });
    } catch (e) {
      setState(() => _isFetchingSlots = false);
    }
  }

  void _confirm() async {
    if (_selectedTime == null) return;
    setState(() => _isLoading = true);
    try {
      // Construct the full DateTime for the appointment
      final timeParts = _selectedTime!.split(':');
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      await AppointmentService.createAppointment(
        providerId: widget.providerId,
        scheduledAt: scheduledAt,
        appointmentType: _appointmentType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked! Pay to confirm.'), backgroundColor: AppColors.accentGreen),
        );
        context.go('/patient/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking failed. Please try again.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.person_rounded, color: AppColors.white, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Book Appointment', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                          const SizedBox(height: 4),
                          Text(
                            _providerData?['full_name']?.toString() ?? 'Loading...',
                            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white, fontSize: 18),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _providerData?['other_specialty']?.toString().isNotEmpty == true
                                ? _providerData!['other_specialty'].toString()
                                : (_providerData?['specialty']?.toString() ?? ''),
                            style: AppTextStyles.caption.copyWith(color: AppColors.sky300),
                          ),
                        ],
                      ),
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

                // Working Hours
                if (_schedules.isNotEmpty) ...[
                  Text('Working Hours', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.sky100.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.sky200),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _schedules.map<Widget>((s) {
                        final day = (s['day']?.toString() ?? '').toString();
                        final dayShort = day.length >= 3 ? '${day[0].toUpperCase()}${day.substring(1, 3)}' : day;
                        final start = s['start_time']?.toString().substring(0, 5) ?? '';
                        final end = s['end_time']?.toString().substring(0, 5) ?? '';
                        final isWorking = s['is_working'] == true;
                        final isSelectedDay = _selectedDate.weekday == (['monday','tuesday','wednesday','thursday','friday','saturday','sunday'].indexOf(day) + 1);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelectedDay ? AppColors.sky500 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelectedDay ? AppColors.sky500 : AppColors.grey200),
                          ),
                          child: Text(
                            isWorking ? '$dayShort $start-$end' : '$dayShort Off',
                            style: AppTextStyles.caption.copyWith(
                              color: isSelectedDay ? Colors.white : (isWorking ? AppColors.darkBlue900 : AppColors.grey400),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

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
                        onTap: () {
                          setState(() { _selectedDate = date; _selectedTime = null; });
                          _loadSlots();
                        },
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
                _isFetchingSlots 
                  ? const Center(child: CircularProgressIndicator())
                  : _timeSlots.isEmpty
                    ? const Center(child: Text("No slots available for this day"))
                    : Wrap(
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
                      : Text('Confirm Booking • XAF $_consultationFee', style: AppTextStyles.labelLarge.copyWith(fontSize: 15)),
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
