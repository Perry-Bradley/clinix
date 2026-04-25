import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});
  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<Options> _authOpts() async {
    final token = await AuthService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _load() async {
    try {
      final opts = await _authOpts();
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final presRes = await dio.get('patients/prescriptions/', options: opts);
      final data = presRes.data;
      List items = data is List ? data : (data is Map ? (data['results'] ?? []) : []);

      List<Map<String, dynamic>> reminders = [];
      try {
        final remRes = await dio.get('consultations/reminders/', options: opts);
        reminders = List<Map<String, dynamic>>.from(remRes.data is List ? remRes.data : []);
      } catch (_) {}

      if (mounted) setState(() {
        _prescriptions = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Prescriptions] Load failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logDose(String reminderId, String status) async {
    try {
      final opts = await _authOpts();
      await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)).post(
        'consultations/reminders/$reminderId/log/',
        data: {'scheduled_time': DateTime.now().toUtc().toIso8601String(), 'status': status},
        options: opts,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'taken' ? 'Marked as taken' : 'Marked as skipped'),
          backgroundColor: status == 'taken' ? AppColors.accentGreen : AppColors.grey500,
        ));
        _load();
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _remindersForPrescription(String prescriptionId) {
    return _reminders.where((r) => r['prescription']?.toString() == prescriptionId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.splashSlate900,
        title: Text('Prescriptions', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.splashSlate900))
          : _prescriptions.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_rounded, size: w * 0.14, color: AppColors.grey200),
                  SizedBox(height: w * 0.04),
                  Text('No prescriptions yet', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.042, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                  SizedBox(height: w * 0.01),
                  Text('Prescriptions from your doctors\nwill appear here', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: AppColors.grey400)),
                ]))
              : RefreshIndicator(
                  color: AppColors.splashSlate900,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: EdgeInsets.all(w * 0.04),
                    itemCount: _prescriptions.length,
                    separatorBuilder: (_, __) => SizedBox(height: w * 0.03),
                    itemBuilder: (_, i) => _buildPrescriptionCard(_prescriptions[i], w),
                  ),
                ),
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> p, double w) {
    final meds = (p['medications'] as List?) ?? [];
    final date = p['issued_at']?.toString().substring(0, 10) ?? '';
    final providerName = p['provider_name']?.toString() ?? p['provider']?.toString() ?? 'Doctor';
    final isValid = p['valid_until'] != null && DateTime.tryParse(p['valid_until'].toString())?.isAfter(DateTime.now()) == true;
    final prescriptionId = p['prescription_id']?.toString() ?? '';
    final pReminders = _remindersForPrescription(prescriptionId);

    return Container(
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: EdgeInsets.all(w * 0.025),
            decoration: BoxDecoration(color: AppColors.splashSlate900.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.receipt_long_rounded, color: AppColors.splashSlate900, size: w * 0.05),
          ),
          SizedBox(width: w * 0.03),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('By $providerName', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.035, fontWeight: FontWeight.w600, color: AppColors.splashSlate900)),
            Text(date, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: AppColors.grey400)),
          ])),
          Container(
            padding: EdgeInsets.symmetric(horizontal: w * 0.02, vertical: w * 0.008),
            decoration: BoxDecoration(
              color: (isValid ? AppColors.accentGreen : AppColors.grey400).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isValid ? 'Active' : 'Expired', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.026, fontWeight: FontWeight.w700, color: isValid ? AppColors.accentGreen : AppColors.grey400)),
          ),
        ]),

        // Medications
        if (meds.isNotEmpty) ...[
          SizedBox(height: w * 0.03),
          ...meds.map((m) {
            final med = m is Map ? m : {};
            final medName = med['name']?.toString() ?? '';
            // Find matching reminder
            final reminder = pReminders.where((r) => r['medication_name'] == medName).toList();
            final hasReminder = reminder.isNotEmpty;
            final reminderId = hasReminder ? reminder.first['id']?.toString() ?? '' : '';
            final adherence = hasReminder ? reminder.first['adherence_rate'] : null;
            final times = hasReminder ? (reminder.first['reminder_times'] as List?) ?? [] : [];

            return Container(
              margin: EdgeInsets.only(bottom: w * 0.025),
              padding: EdgeInsets.all(w * 0.03),
              decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(medName, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, fontWeight: FontWeight.w600, color: AppColors.splashSlate900)),
                    SizedBox(height: w * 0.005),
                    Text('${med['dosage'] ?? ''} · ${med['frequency'] ?? ''} · ${med['duration'] ?? ''}',
                      style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: AppColors.grey500)),
                  ])),
                  if (adherence != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: w * 0.02, vertical: w * 0.008),
                      decoration: BoxDecoration(
                        color: (adherence >= 80 ? AppColors.accentGreen : AppColors.accentOrange).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$adherence%', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.026, fontWeight: FontWeight.w700, color: adherence >= 80 ? AppColors.accentGreen : AppColors.accentOrange)),
                    ),
                ]),
                if (hasReminder && times.isNotEmpty) ...[
                  SizedBox(height: w * 0.02),
                  Row(children: [
                    Icon(Icons.alarm_rounded, size: w * 0.035, color: AppColors.grey400),
                    SizedBox(width: w * 0.015),
                    Text(times.join(', '), style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.026, color: AppColors.grey500)),
                  ]),
                ],
                if (hasReminder && isValid) ...[
                  SizedBox(height: w * 0.025),
                  Row(children: [
                    Expanded(
                      child: SizedBox(
                        height: w * 0.09,
                        child: ElevatedButton.icon(
                          onPressed: () => _logDose(reminderId, 'taken'),
                          icon: Icon(Icons.check_rounded, size: w * 0.04),
                          label: Text('Taken', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.splashSlate900, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                        ),
                      ),
                    ),
                    SizedBox(width: w * 0.02),
                    Expanded(
                      child: SizedBox(
                        height: w * 0.09,
                        child: OutlinedButton.icon(
                          onPressed: () => _logDose(reminderId, 'skipped'),
                          icon: Icon(Icons.close_rounded, size: w * 0.04),
                          label: Text('Skip', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.grey500, side: const BorderSide(color: AppColors.grey200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        ),
                      ),
                    ),
                  ]),
                ],
              ]),
            );
          }),
        ],

        // Instructions
        if (p['instructions'] != null && p['instructions'].toString().isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(w * 0.03),
            decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: w * 0.04, color: AppColors.grey400),
              SizedBox(width: w * 0.02),
              Expanded(child: Text(p['instructions'].toString(), style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: AppColors.grey500, height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }
}
