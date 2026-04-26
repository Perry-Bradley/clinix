import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';

/// Form filled by a doctor at the end of a consultation.
///
/// Becomes part of the patient's medical-record history and can be shared
/// (by the patient) with another doctor on referral.
class MedicalRecordFormPage extends StatefulWidget {
  final String? consultationId;
  final String? patientId;
  // When supplied, the form pre-fills from an AI-drafted MedicalRecord and
  // PATCHes that record on save (flipping is_published=true) instead of
  // POSTing a brand-new one. The doctor reviews + edits before publishing.
  final String? aiDraftRecordId;

  const MedicalRecordFormPage({
    super.key,
    this.consultationId,
    this.patientId,
    this.aiDraftRecordId,
  });

  @override
  State<MedicalRecordFormPage> createState() => _MedicalRecordFormPageState();
}

class _MedicalRecordFormPageState extends State<MedicalRecordFormPage> {
  final _titleCtrl = TextEditingController();
  final _chiefComplaintCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  final _symptomDurationCtrl = TextEditingController();
  final _findingsCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _treatmentCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  DateTime? _followUpDate;
  bool _saving = false;
  String? _error;
  // True while we're fetching the AI draft to pre-fill the form.
  bool _loadingDraft = false;
  bool _isAiDraft = false;
  // Resolved patient id when arriving via the AI-draft path (the draft
  // already knows who the patient is, so the caller doesn't have to pass it).
  String? _resolvedPatientId;
  String? _resolvedConsultationId;

  @override
  void initState() {
    super.initState();
    if (widget.aiDraftRecordId != null && widget.aiDraftRecordId!.isNotEmpty) {
      _isAiDraft = true;
      _loadDraft();
    }
  }

  Future<void> _loadDraft() async {
    setState(() => _loadingDraft = true);
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}records/${widget.aiDraftRecordId}/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      if (data is! Map) return;
      _titleCtrl.text = (data['title'] ?? '').toString();
      _chiefComplaintCtrl.text = (data['chief_complaint'] ?? '').toString();
      final symptoms = data['symptoms'];
      if (symptoms is List) {
        _symptomsCtrl.text = symptoms.join(', ');
      }
      _symptomDurationCtrl.text = (data['symptom_duration'] ?? '').toString();
      _findingsCtrl.text = (data['examination_findings'] ?? '').toString();
      _diagnosisCtrl.text = (data['diagnosis'] ?? '').toString();
      _treatmentCtrl.text = (data['treatment_plan'] ?? '').toString();
      _medicationsCtrl.text = (data['medications_summary'] ?? '').toString();
      final followUp = (data['follow_up_date'] ?? '').toString();
      if (followUp.isNotEmpty) {
        _followUpDate = DateTime.tryParse(followUp);
      }
      _resolvedPatientId = data['patient']?.toString();
      _resolvedConsultationId = data['consultation']?.toString();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the AI draft.');
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _chiefComplaintCtrl.dispose();
    _symptomsCtrl.dispose();
    _symptomDurationCtrl.dispose();
    _findingsCtrl.dispose();
    _diagnosisCtrl.dispose();
    _treatmentCtrl.dispose();
    _medicationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUp() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _followUpDate = picked);
  }

  Future<void> _save() async {
    final patientId = widget.patientId ?? _resolvedPatientId;
    final consultationId = widget.consultationId ?? _resolvedConsultationId;
    if ((patientId == null || patientId.isEmpty) && widget.aiDraftRecordId == null) {
      setState(() => _error = 'Missing patient. Open this form from a consultation.');
      return;
    }
    // Accept any single field filled — doctors don't always have something
    // for every section. Reject only if literally everything is blank.
    final hasContent = [
      _titleCtrl.text,
      _chiefComplaintCtrl.text,
      _symptomsCtrl.text,
      _symptomDurationCtrl.text,
      _findingsCtrl.text,
      _diagnosisCtrl.text,
      _treatmentCtrl.text,
      _medicationsCtrl.text,
    ].any((s) => s.trim().isNotEmpty) || _followUpDate != null;
    if (!hasContent) {
      setState(() => _error = 'Please fill at least one section before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthService.getAccessToken();
      final symptomList = _symptomsCtrl.text
          .split(RegExp(r'[,\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final body = <String, dynamic>{
        if (patientId != null) 'patient': patientId,
        if (consultationId != null) 'consultation': consultationId,
        'title': _titleCtrl.text.trim().isEmpty
            ? 'Consultation report'
            : _titleCtrl.text.trim(),
        'chief_complaint': _chiefComplaintCtrl.text.trim(),
        'symptoms': symptomList,
        'symptom_duration': _symptomDurationCtrl.text.trim(),
        'examination_findings': _findingsCtrl.text.trim(),
        'diagnosis': _diagnosisCtrl.text.trim(),
        'treatment_plan': _treatmentCtrl.text.trim(),
        'medications_summary': _medicationsCtrl.text.trim(),
        if (_followUpDate != null)
          'follow_up_date': DateFormat('yyyy-MM-dd').format(_followUpDate!),
      };

      if (widget.aiDraftRecordId != null && widget.aiDraftRecordId!.isNotEmpty) {
        // Publish the AI draft — flips is_published=true on the server, which
        // fires the patient notification + chat card.
        body['is_published'] = true;
        await Dio().patch(
          '${ApiConstants.baseUrl}${ApiConstants.consultations}records/${widget.aiDraftRecordId}/',
          data: body,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } else {
        await Dio().post(
          '${ApiConstants.baseUrl}${ApiConstants.consultations}records/',
          data: body,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report saved to the patient\u2019s record.')),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/provider/home');
      }
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?.toString() ?? 'Could not save the report.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.darkBlue900,
        title: Text(
          'Patient Report',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.grey200),
        ),
      ),
      body: _loadingDraft
          ? const Center(child: CircularProgressIndicator(color: AppColors.darkBlue500))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _intro(),
            const SizedBox(height: 24),
            _label('Title'),
            _input(_titleCtrl, hint: 'e.g. Initial cardiology consultation'),
            const SizedBox(height: 18),
            _label('Chief complaint'),
            _input(_chiefComplaintCtrl, hint: 'In the patient\u2019s own words…', lines: 2),
            const SizedBox(height: 18),
            _label('Symptoms (comma- or newline-separated)'),
            _input(_symptomsCtrl, hint: 'chest pain, shortness of breath…', lines: 3),
            const SizedBox(height: 18),
            _label('Symptom duration'),
            _input(_symptomDurationCtrl, hint: 'e.g. 3 days, 2 weeks'),
            const SizedBox(height: 18),
            _label('Examination findings'),
            _input(_findingsCtrl, hint: 'Vitals, observations…', lines: 3),
            const SizedBox(height: 18),
            _label('Diagnosis'),
            _input(_diagnosisCtrl, hint: 'Provisional or confirmed', lines: 2),
            const SizedBox(height: 18),
            _label('Treatment plan'),
            _input(_treatmentCtrl,
                hint: 'Course of action, lifestyle, referrals…', lines: 4),
            const SizedBox(height: 18),
            _label('Medications summary'),
            _input(_medicationsCtrl,
                hint: 'Drugs prescribed, dosages, duration…', lines: 3),
            const SizedBox(height: 18),
            _label('Follow-up date'),
            GestureDetector(
              onTap: _pickFollowUp,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  border: Border.all(color: AppColors.grey200),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, color: AppColors.darkBlue600, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _followUpDate == null
                          ? 'Tap to set'
                          : DateFormat('EEEE, d MMMM yyyy').format(_followUpDate!),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _followUpDate == null
                            ? AppColors.grey400
                            : AppColors.darkBlue900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_followUpDate != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _followUpDate = null),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(color: const Color(0xFFB91C1C)),
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isAiDraft ? 'Review & publish report' : 'Save report',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    final aiDraft = _isAiDraft;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkBlue500,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              aiDraft ? Icons.auto_awesome_rounded : Icons.description_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      aiDraft ? 'AI draft' : 'Consultation summary',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (aiDraft) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'BETA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  aiDraft
                      ? 'Drafted from your call recording. Edit anything that\u2019s wrong, then tap "Review & publish" to send it to the patient.'
                      : 'Saved to the patient\u2019s medical record. Patient may share it with another doctor on referral.',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );

  Widget _input(TextEditingController c, {String? hint, int lines = 1}) {
    return TextField(
      controller: c,
      maxLines: lines,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkBlue900),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
        filled: true,
        fillColor: AppColors.grey50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }
}
