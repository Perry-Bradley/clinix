import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';


class BookAppointmentScreen extends StatefulWidget {
  final dynamic doctor;
  const BookAppointmentScreen({super.key, required this.doctor});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _consultationType = 'video';
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.sky500)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _bookAppointment() async {
    if (_selectedDate == null || _selectedTime == null) {
      setState(() => _errorMessage = 'Please select both date and time.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    int platformFee = 15000; // Default fallback
    int serviceCharge = 500;

    try {
      final token = await AuthService.getAccessToken();
      final feeResp = await Dio().get(
        '${ApiConstants.baseUrl}system/settings/fee/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (feeResp.data != null && feeResp.data is Map) {
        final m = feeResp.data as Map<String, dynamic>;
        final cf = m['consultation_fee'];
        final sc = m['service_charge'];
        if (cf != null) platformFee = num.tryParse(cf.toString())?.round() ?? platformFee;
        if (sc != null) serviceCharge = num.tryParse(sc.toString())?.round() ?? serviceCharge;
      }
    } catch (e) {
      debugPrint('Fee fetch failed, using defaults: $e');
    }

    final rawPid = widget.doctor['provider_id'];
    final providerId = rawPid is Map ? (rawPid['user_id'] ?? rawPid['provider_id']) : rawPid;
    final scheduledAt = DateTime(
      _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
      _selectedTime!.hour, _selectedTime!.minute,
    ).toUtc().toIso8601String();

    String appointmentType() {
      switch (_consultationType) {
        case 'in_person':
          return 'in-person';
        case 'video':
        case 'audio':
        default:
          return 'virtual';
      }
    }

    final appointmentPayload = {
      'provider': providerId.toString(),
      'scheduled_at': scheduledAt,
      'appointment_type': appointmentType(),
    };

    if (!mounted) return;
    setState(() => _isLoading = false);

    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    try {
      final token = await AuthService.getAccessToken();
      final bookResp = await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.appointments}',
        data: appointmentPayload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = bookResp.data;
      final appointmentId = data is Map ? data['appointment_id']?.toString() : null;
      if (appointmentId == null || appointmentId.isEmpty) {
        setState(() => _errorMessage = 'Could not create appointment. Please try again.');
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      final paymentSuccessful = await context.push<bool?>(
        '/patient/payment',
        extra: {
          'appointmentId': appointmentId,
          'consultationFee': platformFee,
          'serviceCharge': serviceCharge,
        },
      );

      if (paymentSuccessful != true) {
        if (mounted) setState(() => _errorMessage = 'Payment was not completed. Your appointment is still pending.');
        return;
      }

      if (mounted) {
        setState(() => _successMessage = 'Appointment booked and payment completed.');
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.response?.data?.toString() ?? 'Booking failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.doctor['provider_id']?['first_name'] ?? 'Dr.'} ${widget.doctor['provider_id']?['last_name'] ?? ''}';
    final spec = widget.doctor['specialization'] ?? 'General Practitioner';

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.darkBlue900,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Book Appointment', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white, fontSize: 16)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Doctor summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.darkBlue800, AppColors.sky600]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTextStyles.headlineSmall.copyWith(color: AppColors.white, fontSize: 16)),
                          Text(spec, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Consultation Type
                Text('Consultation Type', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _TypeButton(label: 'Video', icon: Icons.videocam_rounded, value: 'video', selected: _consultationType == 'video', onTap: (v) => setState(() => _consultationType = v)),
                    const SizedBox(width: 10),
                    _TypeButton(label: 'Audio', icon: Icons.phone_rounded, value: 'audio', selected: _consultationType == 'audio', onTap: (v) => setState(() => _consultationType = v)),
                    const SizedBox(width: 10),
                    _TypeButton(label: 'In-Person', icon: Icons.location_on_rounded, value: 'in_person', selected: _consultationType == 'in_person', onTap: (v) => setState(() => _consultationType = v)),
                  ],
                ),
                const SizedBox(height: 24),

                // Date & Time
                Text('Date & Time', style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: AppColors.sky500, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _selectedDate == null ? 'Select date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                style: AppTextStyles.bodyMedium.copyWith(color: _selectedDate == null ? AppColors.grey400 : AppColors.darkBlue800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, color: AppColors.sky500, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _selectedTime == null ? 'Select time' : _selectedTime!.format(context),
                                style: AppTextStyles.bodyMedium.copyWith(color: _selectedTime == null ? AppColors.grey400 : AppColors.darkBlue800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                    child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                  ),
                ],
                if (_successMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accentGreen.withOpacity(0.4))),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_successMessage!, style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _bookAppointment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: AppColors.sky500,
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Book Appointment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 60),
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
  final IconData icon;
  final bool selected;
  final Function(String) onTap;
  const _TypeButton({required this.label, required this.icon, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.sky500 : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.sky500 : AppColors.grey200),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.grey400, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.grey500)),
            ],
          ),
        ),
      ),
    );
  }
}
