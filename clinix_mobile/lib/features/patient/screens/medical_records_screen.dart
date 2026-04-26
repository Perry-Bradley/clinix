import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clinical_pdf.dart';

/// Patient view of their consultation reports.
///
/// Tapping "Share" lets the patient grant another verified doctor read-access
/// to a single record (used when being referred to a different doctor).
class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});
  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}records/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      List items = data is List
          ? data
          : (data is Map ? (data['results'] ?? []) : []);
      if (mounted) {
        setState(() {
          _records = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareRecord(Map<String, dynamic> record) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _ShareRecordSheet(
        recordId: record['record_id']?.toString() ?? '',
        currentlySharedWith:
            (record['shared_with_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
        onChanged: _load,
      ),
    );
  }

  /// Build a clinic-style PDF for the record and hand it to the system share
  /// sheet — patient can save to Files / Drive or send via WhatsApp.
  Future<void> _downloadRecord(Map<String, dynamic> record) async {
    try {
      await ClinicalPdf.shareMedicalRecord(record);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download the record. Please try again.')),
        );
      }
    }
  }

  void _openRecord(Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RecordDetailSheet(
        record: record,
        onShare: () {
          Navigator.pop(ctx);
          _shareRecord(record);
        },
        onDownload: () {
          Navigator.pop(ctx);
          _downloadRecord(record);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        title: Text(
          'Medical Records',
          style: AppTextStyles.headlineMedium.copyWith(
            fontSize: 18,
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.darkBlue900, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.grey200),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 56, color: AppColors.grey200),
                      const SizedBox(height: 16),
                      Text('No medical records yet',
                          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey400)),
                      const SizedBox(height: 4),
                      Text(
                        'Reports from your consultations will appear here.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.sky500,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _RecordCard(
                      record: _records[index],
                      onShare: _shareRecord,
                      onDownload: _downloadRecord,
                      onOpen: _openRecord,
                    ),
                  ),
                ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final Future<void> Function(Map<String, dynamic>) onShare;
  final Future<void> Function(Map<String, dynamic>) onDownload;
  final void Function(Map<String, dynamic>) onOpen;
  const _RecordCard({
    required this.record,
    required this.onShare,
    required this.onDownload,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final title = record['title']?.toString().trim();
    final diagnosis = record['diagnosis']?.toString() ?? 'No diagnosis';
    final treatment = record['treatment_plan']?.toString() ?? '';
    final symptoms = (record['symptoms'] as List?)?.join(', ') ?? '';
    final author = record['authored_by_name']?.toString() ?? 'Doctor';
    final authorSpecialty = record['authored_by_specialty']?.toString();
    final created = record['created_at']?.toString();
    final dateStr = created != null && created.length >= 10
        ? DateFormat('d MMM yyyy').format(DateTime.parse(created))
        : '';
    final sharedCount = (record['shared_with_ids'] as List?)?.length ?? 0;

    return GestureDetector(
      onTap: () => onOpen(record),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkBlue500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.description_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (title?.isNotEmpty == true) ? title! : diagnosis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.darkBlue900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [author, if (authorSpecialty != null && authorSpecialty.isNotEmpty) authorSpecialty]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 11),
              ),
            ],
          ),
          if (diagnosis.isNotEmpty &&
              (title == null || title.isEmpty || title != diagnosis)) ...[
            const SizedBox(height: 12),
            _InfoRow(label: 'Diagnosis', value: diagnosis),
          ],
          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Symptoms', value: symptoms),
          ],
          if (treatment.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Treatment', value: treatment),
          ],
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.grey200),
          const SizedBox(height: 12),
          Row(
            children: [
              if (sharedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.sky100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Shared with $sharedCount',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.sky600,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => onDownload(record),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.download_rounded, color: AppColors.darkBlue500, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Download',
                        style: TextStyle(
                          color: AppColors.darkBlue500,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => onShare(record),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue500,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.share_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _RecordDetailSheet extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  const _RecordDetailSheet({
    required this.record,
    required this.onShare,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final title = (record['title']?.toString().trim().isNotEmpty == true)
        ? record['title'].toString()
        : (record['diagnosis']?.toString() ?? 'Medical Record');
    final author = record['authored_by_name']?.toString() ?? 'Doctor';
    final authorSpecialty = record['authored_by_specialty']?.toString() ?? '';
    final created = record['created_at']?.toString();
    final dateStr = created != null && created.length >= 10
        ? DateFormat('d MMM yyyy').format(DateTime.parse(created))
        : '';
    final symptoms = (record['symptoms'] as List?)?.join(', ') ?? '';

    Widget section(String label, dynamic value) {
      final v = (value ?? '').toString().trim();
      if (v.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.grey500,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              v,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.darkBlue900,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue500,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.description_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: AppColors.darkBlue900,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [author, if (authorSpecialty.isNotEmpty) authorSpecialty, if (dateStr.isNotEmpty) dateStr]
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.grey200),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    section('Chief complaint', record['chief_complaint']),
                    section('Symptoms', symptoms),
                    section('Symptom duration', record['symptom_duration']),
                    section('Examination findings', record['examination_findings']),
                    section('Diagnosis', record['diagnosis']),
                    section('Treatment plan', record['treatment_plan']),
                    section('Medications', record['medications_summary']),
                    section('Follow-up', record['follow_up_date']),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.grey200),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkBlue500,
                        side: const BorderSide(color: AppColors.grey200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBlue500,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareRecordSheet extends StatefulWidget {
  final String recordId;
  final List<String> currentlySharedWith;
  final VoidCallback onChanged;
  const _ShareRecordSheet({
    required this.recordId,
    required this.currentlySharedWith,
    required this.onChanged,
  });

  @override
  State<_ShareRecordSheet> createState() => _ShareRecordSheetState();
}

class _ShareRecordSheetState extends State<_ShareRecordSheet> {
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
        '${ApiConstants.baseUrl}${ApiConstants.consultations}records/${widget.recordId}/share/',
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
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Text(
            'Share with a doctor',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.darkBlue900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'They will see this report only — you can revoke any time.',
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
                borderSide: const BorderSide(color: AppColors.darkBlue800, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No doctors found.',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.grey400),
                          ),
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
                                color: isShared
                                    ? AppColors.darkBlue500
                                    : AppColors.grey200,
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
                                      Text(
                                        specialty,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.darkBlue500,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                isBusy
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : GestureDetector(
                                        onTap: () => _toggle(d),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isShared
                                                ? AppColors.grey50
                                                : AppColors.darkBlue500,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isShared
                                                  ? AppColors.grey200
                                                  : AppColors.darkBlue500,
                                            ),
                                          ),
                                          child: Text(
                                            isShared ? 'Shared' : 'Share',
                                            style: AppTextStyles.caption.copyWith(
                                              color: isShared
                                                  ? AppColors.grey700
                                                  : Colors.white,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 84,
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.grey500,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.darkBlue900,
            fontSize: 13,
          ),
        ),
      ),
    ]);
  }
}
