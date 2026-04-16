import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/appointment_service.dart';

/// Provider writes a prescription for a patient they have an appointment/consultation with.
class WritePrescriptionPage extends StatefulWidget {
  const WritePrescriptionPage({super.key});

  @override
  State<WritePrescriptionPage> createState() => _WritePrescriptionPageState();
}

class _WritePrescriptionPageState extends State<WritePrescriptionPage> {
  bool _loadingPatients = true;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, dynamic>? _selectedAppointment;
  final _instructionsCtrl = TextEditingController();
  final List<_Medication> _meds = [_Medication()];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final all = await AppointmentService.getMyAppointments();
      // Only keep confirmed/completed appointments (has a consultation)
      final usable = all.where((a) {
        final s = a['status']?.toString() ?? '';
        return s == 'confirmed' || s == 'completed';
      }).toList();
      if (mounted) setState(() { _appointments = usable; _loadingPatients = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPatients = false);
    }
  }

  String _patientName(Map<String, dynamic> a) {
    final p = a['patient'];
    if (p is Map) {
      return p['user']?['full_name']?.toString() ?? p['full_name']?.toString() ?? 'Patient';
    }
    return 'Patient';
  }

  Future<void> _submit() async {
    if (_selectedAppointment == null) {
      _toast('Select a patient first');
      return;
    }
    final validMeds = _meds.where((m) => m.nameCtrl.text.trim().isNotEmpty).toList();
    if (validMeds.isEmpty) {
      _toast('Add at least one medication');
      return;
    }
    setState(() => _submitting = true);
    try {
      final consultationId = _selectedAppointment!['consultation_id']?.toString();
      if (consultationId == null || consultationId.isEmpty) {
        _toast('This appointment has no active consultation yet');
        setState(() => _submitting = false);
        return;
      }
      final token = await AuthService.getAccessToken();
      await Dio().post(
        '${ApiConstants.baseUrl}consultations/$consultationId/prescription/',
        data: {
          'medications': validMeds.map((m) => {
            'name': m.nameCtrl.text.trim(),
            'dosage': m.dosageCtrl.text.trim(),
            'frequency': m.frequencyCtrl.text.trim(),
            'duration': m.durationCtrl.text.trim(),
          }).toList(),
          'instructions': _instructionsCtrl.text.trim(),
          'is_digital': true,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription sent'), backgroundColor: AppColors.accentGreen),
      );
      context.pop();
    } catch (e) {
      _toast('Failed to submit prescription');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    for (final m in _meds) { m.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        title: Text('New Prescription', style: AppTextStyles.headlineSmall.copyWith(fontSize: 17)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: _loadingPatients
          ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionHeader('Patient'),
                const SizedBox(height: 10),
                _patientSelector(),
                const SizedBox(height: 24),
                _SectionHeader('Medications'),
                const SizedBox(height: 10),
                ...List.generate(_meds.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MedicationCard(
                    med: _meds[i],
                    index: i + 1,
                    canRemove: _meds.length > 1,
                    onRemove: () => setState(() { _meds[i].dispose(); _meds.removeAt(i); }),
                  ),
                )),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _meds.add(_Medication())),
                  icon: const Icon(Icons.add_rounded, color: AppColors.sky500),
                  label: Text('Add medication', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.sky200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader('Additional instructions'),
                const SizedBox(height: 10),
                TextField(
                  controller: _instructionsCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'e.g. Take after meals. Avoid dairy during treatment.',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.grey200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.grey200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.sky500)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded),
                    label: Text(_submitting ? 'Sending...' : 'Submit Prescription',
                        style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sky500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _patientSelector() {
    if (_appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.grey400),
          const SizedBox(width: 10),
          Expanded(child: Text('No confirmed appointments yet. Prescriptions can be written only for patients with an active consultation.', style: AppTextStyles.caption.copyWith(color: AppColors.grey500, height: 1.4))),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedAppointment,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Choose a patient', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
          ),
          icon: const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.grey400)),
          items: _appointments.map((a) => DropdownMenuItem(
            value: a,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Text(_patientName(a), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkBlue900)),
            ),
          )).toList(),
          onChanged: (v) => setState(() => _selectedAppointment = v),
        ),
      ),
    );
  }
}

class _Medication {
  final nameCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  final frequencyCtrl = TextEditingController();
  final durationCtrl = TextEditingController();
  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    frequencyCtrl.dispose();
    durationCtrl.dispose();
  }
}

class _MedicationCard extends StatelessWidget {
  final _Medication med;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  const _MedicationCard({required this.med, required this.index, required this.canRemove, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.sky100, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.medication_rounded, color: AppColors.sky500, size: 16),
            ),
            const SizedBox(width: 8),
            Text('Medication $index', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
            const Spacer(),
            if (canRemove)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.grey400),
                visualDensity: VisualDensity.compact,
              ),
          ]),
          _field(med.nameCtrl, 'Drug name', 'e.g. Amoxicillin 500mg'),
          _field(med.dosageCtrl, 'Dosage', 'e.g. 1 tablet'),
          _field(med.frequencyCtrl, 'Frequency', 'e.g. 3 times a day'),
          _field(med.durationCtrl, 'Duration', 'e.g. 7 days'),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: c,
        style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: AppColors.grey50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Text(title, style: AppTextStyles.headlineSmall.copyWith(fontSize: 15));
}
