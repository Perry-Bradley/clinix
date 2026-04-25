import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';

/// Doctor-issued referral.
///
/// Two kinds, gated by a tab at the top:
/// * Specialist  → pick another verified doctor on the platform.
/// * Lab Test    → name a hospital + the test (no doctor on the other end).
///
/// Both kinds attach to the patient's record so the destination provider
/// (or the patient when at the lab) has all the necessary context.
class ReferralFormPage extends StatefulWidget {
  final String patientId;
  final String? medicalRecordId;
  const ReferralFormPage({super.key, required this.patientId, this.medicalRecordId});

  @override
  State<ReferralFormPage> createState() => _ReferralFormPageState();
}

class _ReferralFormPageState extends State<ReferralFormPage> {
  String _kind = 'specialist'; // 'specialist' | 'lab_test'

  // Specialist fields
  Map<String, dynamic>? _selectedSpecialty;
  List<Map<String, dynamic>> _specialties = const [];
  Map<String, dynamic>? _selectedDoctor;
  List<Map<String, dynamic>> _doctors = const [];
  bool _loadingDoctors = false;

  // Lab test fields
  final _hospitalCtrl = TextEditingController();
  final _hospitalAddressCtrl = TextEditingController();
  final _testCtrl = TextEditingController();

  // Shared
  final _reasonCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpecialties();
  }

  @override
  void dispose() {
    _hospitalCtrl.dispose();
    _hospitalAddressCtrl.dispose();
    _testCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSpecialties() async {
    try {
      final res = await Dio().get('${ApiConstants.baseUrl}providers/specialties/');
      final data = res.data;
      if (data is List) {
        setState(() {
          _specialties = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDoctorsForSpecialty(String specialtyId) async {
    setState(() {
      _loadingDoctors = true;
      _selectedDoctor = null;
      _doctors = const [];
    });
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}providers/nearby/',
        queryParameters: {'specialty_id': specialtyId, 'role': 'specialist'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      List items = data is List ? data : (data is Map ? data['results'] ?? [] : []);
      setState(() {
        _doctors = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please add a short reason for the referral.');
      return;
    }
    if (_kind == 'specialist' && _selectedDoctor == null) {
      setState(() => _error = 'Pick the specialist you are referring to.');
      return;
    }
    if (_kind == 'lab_test' &&
        (_hospitalCtrl.text.trim().isEmpty || _testCtrl.text.trim().isEmpty)) {
      setState(() => _error = 'Hospital and test name are both required.');
      return;
    }

    setState(() => _saving = true);
    try {
      final token = await AuthService.getAccessToken();
      final payload = <String, dynamic>{
        'kind': _kind,
        'patient': widget.patientId,
        'reason': _reasonCtrl.text.trim(),
        if (widget.medicalRecordId != null) 'medical_record': widget.medicalRecordId,
      };
      if (_kind == 'specialist') {
        payload['referred_to'] = _selectedDoctor!['provider_id'];
      } else {
        payload['target_hospital_name'] = _hospitalCtrl.text.trim();
        payload['target_hospital_address'] = _hospitalAddressCtrl.text.trim();
        payload['test_name'] = _testCtrl.text.trim();
      }

      await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}referrals/',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _kind == 'specialist'
                ? 'Specialist referral created.'
                : 'Lab test referral created.',
          ),
        ),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/provider/home');
      }
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?.toString() ?? 'Could not submit referral.');
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
          'Refer Patient',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kindSwitcher(),
            const SizedBox(height: 24),
            if (_kind == 'specialist') ..._buildSpecialistFields(),
            if (_kind == 'lab_test') ..._buildLabTestFields(),
            const SizedBox(height: 18),
            _label('Reason for referral *'),
            _input(_reasonCtrl,
                hint: 'Why are you referring this patient?', lines: 4),
            if (widget.medicalRecordId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sky100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.sky600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your latest consultation report is attached.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.sky600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
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
                        _kind == 'specialist' ? 'Send referral' : 'Send lab referral',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindSwitcher() {
    Widget tab(String value, IconData icon, String title, String sub) {
      final selected = _kind == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _kind = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.only(right: value == 'specialist' ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.darkBlue800 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.darkBlue800 : AppColors.grey200,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: selected ? Colors.white : AppColors.darkBlue800, size: 22),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: selected ? Colors.white : AppColors.darkBlue900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: selected ? Colors.white.withOpacity(0.85) : AppColors.grey500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('specialist', Icons.local_hospital_rounded, 'Specialist',
            'Refer to another doctor'),
        tab('lab_test', Icons.science_rounded, 'Lab Test',
            'Send to a hospital'),
      ],
    );
  }

  List<Widget> _buildSpecialistFields() {
    return [
      _label('Specialty'),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: _selectedSpecialty?['specialty_id']?.toString(),
        decoration: _decoration('Pick a specialty'),
        items: _specialties
            .map((s) => DropdownMenuItem<String>(
                  value: s['specialty_id']?.toString(),
                  child: Text(s['name']?.toString() ?? ''),
                ))
            .toList(),
        onChanged: (v) {
          final picked = _specialties.firstWhere(
            (s) => s['specialty_id']?.toString() == v,
            orElse: () => const {},
          );
          setState(() => _selectedSpecialty = picked.isEmpty ? null : picked);
          if (v != null) _loadDoctorsForSpecialty(v);
        },
        style: TextStyle(color: AppColors.darkBlue900, fontWeight: FontWeight.w600),
        dropdownColor: Colors.white,
      ),
      const SizedBox(height: 18),
      _label('Doctor'),
      const SizedBox(height: 6),
      if (_selectedSpecialty == null)
        _hint('Pick a specialty first')
      else if (_loadingDoctors)
        _hint('Loading doctors…')
      else if (_doctors.isEmpty)
        _hint('No verified doctors found for this specialty.')
      else
        ..._doctors.map((d) {
          final selected = _selectedDoctor != null &&
              _selectedDoctor!['provider_id'] == d['provider_id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedDoctor = d),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? AppColors.sky100 : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.darkBlue800 : AppColors.grey200,
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.sky400, AppColors.darkBlue800],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_hospital_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['full_name']?.toString() ?? 'Doctor',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkBlue900,
                          ),
                        ),
                        Text(
                          (d['specialty_name'] ??
                                  d['other_specialty'] ??
                                  d['specialty'] ??
                                  '')
                              .toString(),
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.darkBlue800, size: 22),
                ],
              ),
            ),
          );
        }),
    ];
  }

  List<Widget> _buildLabTestFields() {
    return [
      _label('Hospital / facility *'),
      _input(_hospitalCtrl, hint: 'e.g. Laquintinie Hospital, Douala'),
      const SizedBox(height: 18),
      _label('Address (optional)'),
      _input(_hospitalAddressCtrl, hint: 'Street / district…'),
      const SizedBox(height: 18),
      _label('Test name *'),
      _input(_testCtrl, hint: 'e.g. Full Blood Count, Chest X-Ray'),
    ];
  }

  Widget _label(String text) => Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.darkBlue900,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      );

  Widget _hint(String text) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Text(text,
            style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
      );

  Widget _input(TextEditingController c, {String? hint, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        controller: c,
        maxLines: lines,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkBlue900),
        decoration: _decoration(hint ?? ''),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
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
      );
}
