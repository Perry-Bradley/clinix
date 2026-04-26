import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clinical_pdf.dart';

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

  Future<void> _downloadPrescription(Map<String, dynamic> p) async {
    try {
      await ClinicalPdf.sharePrescription(p);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download the prescription. Please try again.')),
        );
      }
    }
  }

  Future<void> _sharePrescription(Map<String, dynamic> p) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _SharePrescriptionSheet(
        prescriptionId: p['prescription_id']?.toString() ?? '',
        currentlySharedWith:
            (p['shared_with_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
        onChanged: _load,
      ),
    );
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

        SizedBox(height: w * 0.03),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => _downloadPrescription(p),
              child: Container(
                margin: EdgeInsets.only(right: w * 0.02),
                padding: EdgeInsets.symmetric(horizontal: w * 0.035, vertical: w * 0.022),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded, color: AppColors.darkBlue500, size: w * 0.04),
                    SizedBox(width: w * 0.015),
                    Text(
                      'Download',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.darkBlue500,
                        fontWeight: FontWeight.w800,
                        fontSize: w * 0.03,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _sharePrescription(p),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.035, vertical: w * 0.022),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue500,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_rounded, color: Colors.white, size: w * 0.04),
                    SizedBox(width: w * 0.015),
                    Text(
                      'Share',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: w * 0.03,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _SharePrescriptionSheet extends StatefulWidget {
  final String prescriptionId;
  final List<String> currentlySharedWith;
  final VoidCallback onChanged;
  const _SharePrescriptionSheet({
    required this.prescriptionId,
    required this.currentlySharedWith,
    required this.onChanged,
  });

  @override
  State<_SharePrescriptionSheet> createState() => _SharePrescriptionSheetState();
}

class _SharePrescriptionSheetState extends State<_SharePrescriptionSheet> {
  String _query = '';
  List<Map<String, dynamic>> _doctors = [];
  bool _loading = true;
  Set<String> _shared = {};
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _shared = widget.currentlySharedWith.toSet();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}providers/nearby/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      List raw = data is List ? data : (data is Map ? data['results'] ?? [] : []);
      if (mounted) {
        setState(() {
          _doctors = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> doctor) async {
    final id = doctor['provider_id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _busyId = id);
    try {
      final token = await AuthService.getAccessToken();
      final isShared = _shared.contains(id);
      await Dio().post(
        '${ApiConstants.baseUrl}consultations/prescriptions/${widget.prescriptionId}/share/',
        data: {'provider_id': id, 'revoke': isShared},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        if (isShared) {
          _shared.remove(id);
        } else {
          _shared.add(id);
        }
      });
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update sharing status.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _doctors.where((d) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final name = (d['full_name'] ?? '').toString().toLowerCase();
      final specialty = [
        d['specialty_name'],
        d['specialty'],
        d['other_specialty'],
      ].where((s) => s != null).join(' ').toLowerCase();
      return name.contains(q) || specialty.contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Text(
            'Share with a doctor',
            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.darkBlue900, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'They will see this prescription only — you can revoke any time.',
            style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search doctors, specialty…',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
              filled: true,
              fillColor: AppColors.grey50,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.darkBlue500, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.darkBlue500)),
                  )
                : filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text('No doctors found.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final d = filtered[i];
                          final id = d['provider_id']?.toString() ?? '';
                          final name = d['full_name']?.toString() ?? 'Doctor';
                          final specialty = (d['specialty_name'] ??
                                  d['other_specialty'] ??
                                  d['specialty'] ??
                                  'General')
                              .toString();
                          final isShared = _shared.contains(id);
                          final isBusy = _busyId == id;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: isShared ? AppColors.darkBlue500 : AppColors.grey200,
                                width: isShared ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppColors.darkBlue500,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _initials(name),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.darkBlue900,
                                        ),
                                      ),
                                      Text(specialty, style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
                                    ],
                                  ),
                                ),
                                isBusy
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                    : GestureDetector(
                                        onTap: () => _toggle(d),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isShared ? AppColors.grey50 : AppColors.darkBlue500,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isShared ? AppColors.grey200 : AppColors.darkBlue500,
                                            ),
                                          ),
                                          child: Text(
                                            isShared ? 'Shared' : 'Share',
                                            style: AppTextStyles.caption.copyWith(
                                              color: isShared ? AppColors.grey700 : Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _initials(String fullName) {
    final cleaned = fullName
        .replaceAll(RegExp(r'^(Dr\.?|Doctor|Mr\.?|Mrs\.?|Ms\.?)\s+', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
