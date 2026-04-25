import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

class MedicationRemindersScreen extends StatefulWidget {
  const MedicationRemindersScreen({super.key});
  @override
  State<MedicationRemindersScreen> createState() => _MedicationRemindersScreenState();
}

class _MedicationRemindersScreenState extends State<MedicationRemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  Map<String, dynamic>? _adherence;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Options> _authOpts() async {
    final token = await AuthService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _load() async {
    try {
      final opts = await _authOpts();
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final res = await dio.get('consultations/reminders/', options: opts);
      final adhRes = await dio.get('consultations/reminders/adherence/', options: opts);
      if (!mounted) return;
      setState(() {
        _reminders = List<Map<String, dynamic>>.from(res.data is List ? res.data : []);
        _adherence = adhRes.data is Map ? Map<String, dynamic>.from(adhRes.data) : null;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Reminders] Load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logDose(String reminderId, String status) async {
    try {
      final opts = await _authOpts();
      final now = DateTime.now();
      await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)).post(
        'consultations/reminders/$reminderId/log/',
        data: {
          'scheduled_time': now.toUtc().toIso8601String(),
          'status': status,
        },
        options: opts,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'taken' ? 'Marked as taken' : 'Marked as skipped'),
            backgroundColor: status == 'taken' ? AppColors.accentGreen : AppColors.grey500,
          ),
        );
        _load();
      }
    } catch (e) {
      debugPrint('[Reminders] Log failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.splashSlate900,
        surfaceTintColor: Colors.transparent,
        title: Text('Medication Reminders', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.splashSlate900))
          : _reminders.isEmpty
              ? _emptyState(w)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.splashSlate900,
                  child: ListView(
                    padding: EdgeInsets.all(w * 0.05),
                    children: [
                      if (_adherence != null) _adherenceCard(w),
                      SizedBox(height: w * 0.04),
                      Text('Active Medications', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                      SizedBox(height: w * 0.03),
                      ..._reminders.map((r) => _reminderCard(r, w)),
                      SizedBox(height: w * 0.1),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyState(double w) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(w * 0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_rounded, size: w * 0.15, color: AppColors.grey200),
            SizedBox(height: w * 0.04),
            Text('No Active Reminders', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
            SizedBox(height: w * 0.02),
            Text('When your doctor prescribes medication,\nreminders will appear here automatically.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.033, color: AppColors.grey500, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _adherenceCard(double w) {
    final overall = _adherence?['overall'];
    final percentage = overall != null ? '$overall%' : '--';
    final color = overall != null && overall >= 80 ? AppColors.accentGreen : (overall != null && overall >= 50 ? AppColors.accentOrange : AppColors.error);

    return Container(
      padding: EdgeInsets.all(w * 0.045),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.splashSlate900, AppColors.splashSlate800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adherence Rate', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: Colors.white60)),
                SizedBox(height: w * 0.01),
                Text(percentage, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.08, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: w * 0.01),
                Text(
                  overall == null ? 'No data yet' : overall >= 80 ? 'Excellent compliance' : overall >= 50 ? 'Needs improvement' : 'Low adherence — stay on track',
                  style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: Colors.white54),
                ),
              ],
            ),
          ),
          SizedBox(
            width: w * 0.18,
            height: w * 0.18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: w * 0.16,
                  height: w * 0.16,
                  child: CircularProgressIndicator(
                    value: overall != null ? overall / 100 : 0,
                    strokeWidth: w * 0.015,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Icon(Icons.medication_rounded, color: Colors.white, size: w * 0.06),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderCard(Map<String, dynamic> r, double w) {
    final name = r['medication_name']?.toString() ?? '';
    final dosage = r['dosage']?.toString() ?? '';
    final frequency = r['frequency']?.toString() ?? '';
    final times = (r['reminder_times'] as List?) ?? [];
    final endDate = r['end_date']?.toString() ?? '';
    final adherenceRate = r['adherence_rate'];
    final id = r['id']?.toString() ?? '';

    String daysLeft = '';
    if (endDate.isNotEmpty) {
      final end = DateTime.tryParse(endDate);
      if (end != null) {
        final diff = end.difference(DateTime.now()).inDays;
        daysLeft = diff > 0 ? '$diff days left' : 'Ending today';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: w * 0.03),
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(w * 0.025),
                decoration: BoxDecoration(color: AppColors.splashSlate900.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.medication_rounded, color: AppColors.splashSlate900, size: w * 0.05),
              ),
              SizedBox(width: w * 0.03),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                    SizedBox(height: w * 0.005),
                    Text('$dosage · $frequency', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: AppColors.grey500)),
                  ],
                ),
              ),
              if (adherenceRate != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.025, vertical: w * 0.01),
                  decoration: BoxDecoration(
                    color: (adherenceRate >= 80 ? AppColors.accentGreen : AppColors.accentOrange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$adherenceRate%', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, fontWeight: FontWeight.w700, color: adherenceRate >= 80 ? AppColors.accentGreen : AppColors.accentOrange)),
                ),
            ],
          ),
          SizedBox(height: w * 0.03),
          // Schedule times
          Wrap(
            spacing: w * 0.02,
            runSpacing: w * 0.02,
            children: times.map<Widget>((t) => Container(
              padding: EdgeInsets.symmetric(horizontal: w * 0.025, vertical: w * 0.012),
              decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(8)),
              child: Text(t.toString(), style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, fontWeight: FontWeight.w600, color: AppColors.splashSlate900)),
            )).toList(),
          ),
          if (daysLeft.isNotEmpty) ...[
            SizedBox(height: w * 0.02),
            Text(daysLeft, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.026, color: AppColors.grey400)),
          ],
          SizedBox(height: w * 0.03),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: w * 0.11,
                  child: ElevatedButton.icon(
                    onPressed: () => _logDose(id, 'taken'),
                    icon: Icon(Icons.check_rounded, size: w * 0.045),
                    label: Text('Taken', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.splashSlate900,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              SizedBox(width: w * 0.025),
              Expanded(
                child: SizedBox(
                  height: w * 0.11,
                  child: OutlinedButton.icon(
                    onPressed: () => _logDose(id, 'skipped'),
                    icon: Icon(Icons.close_rounded, size: w * 0.045),
                    label: Text('Skip', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.grey500,
                      side: const BorderSide(color: AppColors.grey200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
