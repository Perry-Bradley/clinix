import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/medication_alarm_service.dart';

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
      // (Re)schedule the on-device alarms to match the active reminders.
      await MedicationAlarmService.syncAlarms(_reminders);
    } catch (e) {
      debugPrint('[Reminders] Load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The dose slot this tap refers to: the closest scheduled time today.
  /// Logging against the slot (not "now") lets the backend flip that slot
  /// from missed → taken instead of recording a stray extra dose.
  DateTime _nearestSlot(Map<String, dynamic> reminder) {
    final now = DateTime.now();
    final times = (reminder['reminder_times'] as List?) ?? const [];
    DateTime? best;
    int bestDiff = 1 << 30;
    for (final t in times) {
      final parts = t.toString().split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      final slot = DateTime(now.year, now.month, now.day, h, m);
      final diff = (now.difference(slot)).inMinutes.abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = slot;
      }
    }
    return best ?? now;
  }

  Future<void> _logDose(Map<String, dynamic> reminder, String status) async {
    final reminderId = reminder['id']?.toString() ?? '';
    if (reminderId.isEmpty) return;
    try {
      final opts = await _authOpts();
      final slot = _nearestSlot(reminder);
      await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)).post(
        'consultations/reminders/$reminderId/log/',
        data: {
          'scheduled_time': slot.toUtc().toIso8601String(),
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
                    onPressed: () => _logDose(r, 'taken'),
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
                    onPressed: () => _logDose(r, 'skipped'),
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
          SizedBox(height: w * 0.015),
          Center(
            child: TextButton.icon(
              onPressed: () => _showHistory(r),
              icon: Icon(Icons.history_rounded, size: w * 0.04, color: AppColors.splashSlate900),
              label: Text(
                'Dose history',
                style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.031, fontWeight: FontWeight.w700, color: AppColors.splashSlate900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dose history ─────────────────────────────────────────────────────────

  Future<void> _showHistory(Map<String, dynamic> r) async {
    final id = r['id']?.toString() ?? '';
    if (id.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _DoseHistorySheet(reminderId: id, authOpts: _authOpts),
    );
  }
}

/// Bottom sheet listing the last 7 days of dose slots with their status —
/// taken, skipped, missed, or upcoming.
class _DoseHistorySheet extends StatefulWidget {
  final String reminderId;
  final Future<Options> Function() authOpts;
  const _DoseHistorySheet({required this.reminderId, required this.authOpts});

  @override
  State<_DoseHistorySheet> createState() => _DoseHistorySheetState();
}

class _DoseHistorySheetState extends State<_DoseHistorySheet> {
  List<Map<String, dynamic>> _slots = [];
  String _medName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final opts = await widget.authOpts();
      final res = await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)).get(
        'consultations/reminders/${widget.reminderId}/log/',
        options: opts,
      );
      final data = res.data;
      if (mounted && data is Map) {
        setState(() {
          _medName = data['medication_name']?.toString() ?? '';
          _slots = List<Map<String, dynamic>>.from(
              (data['slots'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  (Color, IconData, String) _statusStyle(String status) {
    switch (status) {
      case 'taken':
        return (AppColors.accentGreen, Icons.check_circle_rounded, 'Taken');
      case 'skipped':
        return (AppColors.accentOrange, Icons.remove_circle_rounded, 'Skipped');
      case 'missed':
        return (AppColors.error, Icons.cancel_rounded, 'Missed');
      default:
        return (AppColors.grey400, Icons.schedule_rounded, 'Upcoming');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: EdgeInsets.fromLTRB(w * 0.06, w * 0.04, w * 0.06, w * 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            SizedBox(height: w * 0.04),
            Text(
              _medName.isEmpty ? 'Dose history' : '$_medName — last 7 days',
              style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.042, fontWeight: FontWeight.w800, color: AppColors.splashSlate900),
            ),
            SizedBox(height: w * 0.03),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.splashSlate900)),
              )
            else if (_slots.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No doses scheduled yet.', style: TextStyle(fontFamily: 'Inter', color: AppColors.grey500, fontSize: w * 0.034)),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _slots.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, i) {
                    final s = _slots[i];
                    final dt = DateTime.tryParse(s['scheduled_time']?.toString() ?? '')?.toLocal();
                    final (color, icon, label) = _statusStyle(s['status']?.toString() ?? '');
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: w * 0.025),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: w * 0.05),
                          SizedBox(width: w * 0.03),
                          Expanded(
                            child: Text(
                              dt == null ? '—' : DateFormat('EEE d MMM · HH:mm').format(dt),
                              style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, fontWeight: FontWeight.w600, color: AppColors.splashSlate900),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: w * 0.025, vertical: w * 0.01),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, fontWeight: FontWeight.w700, color: color)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
