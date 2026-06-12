import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clinical_pdf.dart';

/// Full view of one prescription: every medication with its schedule,
/// adherence, Taken/Skip actions and a per-medication dose history —
/// so the patient tracks the whole course in one place.
class PrescriptionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> prescription;
  const PrescriptionDetailScreen({super.key, required this.prescription});

  @override
  State<PrescriptionDetailScreen> createState() => _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState extends State<PrescriptionDetailScreen> {
  List<Map<String, dynamic>> _reminders = [];
  final Map<String, List<Map<String, dynamic>>> _historyByReminder = {};
  final Set<String> _expanded = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Options> _auth() async {
    final token = await AuthService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  String get _prescriptionId => widget.prescription['prescription_id']?.toString() ?? '';

  Future<void> _load() async {
    try {
      final res = await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
          .get('consultations/reminders/', options: await _auth());
      final all = List<Map<String, dynamic>>.from(res.data is List ? res.data : []);
      if (mounted) {
        setState(() {
          _reminders = all.where((r) => r['prescription']?.toString() == _prescriptionId).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _reminderForMed(String medName) {
    for (final r in _reminders) {
      if (r['medication_name']?.toString() == medName) return r;
    }
    return null;
  }

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
      final diff = now.difference(slot).inMinutes.abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = slot;
      }
    }
    return best ?? now;
  }

  Future<void> _logDose(Map<String, dynamic> reminder, String status) async {
    final id = reminder['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl)).post(
        'consultations/reminders/$id/log/',
        data: {
          'scheduled_time': _nearestSlot(reminder).toUtc().toIso8601String(),
          'status': status,
        },
        options: await _auth(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'taken' ? 'Marked as taken' : 'Marked as skipped'),
          backgroundColor: status == 'taken' ? AppColors.accentGreen : AppColors.grey500,
        ));
      }
      _historyByReminder.remove(id); // force-refresh history on next expand
      await _load();
      if (_expanded.contains(id)) await _loadHistory(id);
    } catch (_) {}
  }

  Future<void> _loadHistory(String reminderId) async {
    try {
      final res = await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
          .get('consultations/reminders/$reminderId/log/', options: await _auth());
      final data = res.data;
      if (mounted && data is Map) {
        setState(() {
          _historyByReminder[reminderId] = List<Map<String, dynamic>>.from(
              (data['slots'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const []);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleHistory(String reminderId) async {
    setState(() {
      if (_expanded.contains(reminderId)) {
        _expanded.remove(reminderId);
      } else {
        _expanded.add(reminderId);
      }
    });
    if (_expanded.contains(reminderId) && !_historyByReminder.containsKey(reminderId)) {
      await _loadHistory(reminderId);
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
    final p = widget.prescription;
    final w = MediaQuery.of(context).size.width;
    final meds = (p['medications'] as List?) ?? [];
    final providerName = p['provider_name']?.toString() ?? 'Doctor';
    final issued = p['issued_at']?.toString();
    final issuedLabel = issued != null && issued.length >= 10
        ? DateFormat('d MMM yyyy').format(DateTime.tryParse(issued) ?? DateTime.now())
        : '';
    final isValid = p['valid_until'] != null &&
        DateTime.tryParse(p['valid_until'].toString())?.isAfter(DateTime.now()) == true;
    final instructions = p['instructions']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        title: Text(
          'Prescription',
          style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w800, color: AppColors.darkBlue900),
        ),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: () async {
              try {
                await ClinicalPdf.sharePrescription(p);
              } catch (_) {}
            },
            icon: const Icon(Icons.download_rounded, color: AppColors.darkBlue900),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.darkBlue900))
          : RefreshIndicator(
              color: AppColors.darkBlue900,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(w * 0.05, 8, w * 0.05, 40),
                children: [
                  // ── Header card ──
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue900,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prescribed by $providerName',
                                  style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                              const SizedBox(height: 3),
                              Text(issuedLabel,
                                  style: const TextStyle(fontFamily: 'Inter', color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isValid ? AppColors.accentGreen : Colors.white38).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isValid ? 'Active' : 'Expired',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isValid ? const Color(0xFF6EE7B7) : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Medications with tracking ──
                  Text('Medications',
                      style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w800, color: AppColors.darkBlue900)),
                  const SizedBox(height: 10),
                  ...meds.map((m) {
                    final med = m is Map ? m : {};
                    final medName = med['name']?.toString() ?? '';
                    final reminder = _reminderForMed(medName);
                    final reminderId = reminder?['id']?.toString() ?? '';
                    final adherence = reminder?['adherence_rate'];
                    final times = (reminder?['reminder_times'] as List?) ?? const [];
                    final expanded = _expanded.contains(reminderId);
                    final history = _historyByReminder[reminderId];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
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
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.darkBlue900.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.medication_rounded, color: AppColors.darkBlue900, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(medName,
                                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.darkBlue900)),
                                    const SizedBox(height: 2),
                                    Text(
                                      [med['dosage'], med['frequency'], med['duration']]
                                          .where((e) => (e?.toString() ?? '').isNotEmpty)
                                          .join(' · '),
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.grey500),
                                    ),
                                  ],
                                ),
                              ),
                              if (adherence != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ((adherence as num) >= 80 ? AppColors.accentGreen : AppColors.accentOrange).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text('$adherence%',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: adherence >= 80 ? AppColors.accentGreen : AppColors.accentOrange,
                                      )),
                                ),
                            ],
                          ),
                          if (times.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.alarm_rounded, size: 14, color: AppColors.grey400),
                                const SizedBox(width: 6),
                                Text(times.join('  ·  '),
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
                              ],
                            ),
                          ],
                          if (reminder != null && isValid) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _logDose(reminder, 'taken'),
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('Taken', style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w800)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.darkBlue900,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _logDose(reminder, 'skipped'),
                                      icon: const Icon(Icons.close_rounded, size: 16),
                                      label: const Text('Skip', style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w800)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.grey500,
                                        side: const BorderSide(color: AppColors.grey200),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => _toggleHistory(reminderId),
                                icon: Icon(
                                  expanded ? Icons.expand_less_rounded : Icons.history_rounded,
                                  size: 16,
                                  color: AppColors.darkBlue900,
                                ),
                                label: Text(
                                  expanded ? 'Hide history' : 'Dose history',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.darkBlue900),
                                ),
                              ),
                            ),
                            if (expanded)
                              history == null
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(
                                        child: SizedBox(
                                          width: 18, height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBlue900),
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: history.take(14).map((s) {
                                        final dt = DateTime.tryParse(s['scheduled_time']?.toString() ?? '')?.toLocal();
                                        final (color, icon, label) = _statusStyle(s['status']?.toString() ?? '');
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 5),
                                          child: Row(
                                            children: [
                                              Icon(icon, color: color, size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  dt == null ? '—' : DateFormat('EEE d MMM · HH:mm').format(dt),
                                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkBlue900),
                                                ),
                                              ),
                                              Text(label,
                                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                          ] else if (reminder == null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'No reminder schedule for this medication.',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.grey400),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  // ── Instructions ──
                  if (instructions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text("Doctor's instructions",
                        style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w800, color: AppColors.darkBlue900)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.grey50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        instructions,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.grey700, height: 1.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
