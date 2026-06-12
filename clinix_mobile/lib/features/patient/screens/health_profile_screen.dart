import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

/// Basic health data the patient shares with their doctors — filled in once
/// after signup (skippable) and editable any time from the Profile tab.
/// Doctors see it on the appointment before the consultation starts.
class HealthProfileScreen extends StatefulWidget {
  /// Intake mode shows a welcome header + "Skip for now" and routes to the
  /// home screen when done; edit mode is a plain editor that pops back.
  final bool isIntake;
  const HealthProfileScreen({super.key, this.isIntake = false});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _medsCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  String? _bloodType;
  bool _loading = true;
  bool _saving = false;

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _heightCtrl, _weightCtrl, _tempCtrl, _pulseCtrl, _allergiesCtrl,
      _conditionsCtrl, _medsCtrl, _emergencyNameCtrl, _emergencyPhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Options> _auth() async {
    final token = await AuthService.getAccessToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  String _num(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    return s == 'null' ? '' : s;
  }

  Future<void> _load() async {
    try {
      final res = await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
          .get('patients/profile/', options: await _auth());
      final d = res.data is Map ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _heightCtrl.text = _num(d['height_cm']);
        _weightCtrl.text = _num(d['weight_kg']);
        _tempCtrl.text = _num(d['temperature_c']);
        _pulseCtrl.text = _num(d['pulse_bpm']);
        _medsCtrl.text = _num(d['current_medications']);
        _emergencyNameCtrl.text = _num(d['emergency_contact_name']);
        _emergencyPhoneCtrl.text = _num(d['emergency_contact_phone']);
        final bt = _num(d['blood_type']);
        _bloodType = _bloodTypes.contains(bt) ? bt : null;
        _allergiesCtrl.text = ((d['allergies'] as List?) ?? []).join(', ');
        _conditionsCtrl.text = ((d['chronic_conditions'] as List?) ?? []).join(', ');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _splitList(String raw) => raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'health_profile_completed': true,
        'blood_type': _bloodType ?? '',
        'allergies': _splitList(_allergiesCtrl.text),
        'chronic_conditions': _splitList(_conditionsCtrl.text),
        'current_medications': _medsCtrl.text.trim(),
        'emergency_contact_name': _emergencyNameCtrl.text.trim(),
        'emergency_contact_phone': _emergencyPhoneCtrl.text.trim(),
      };
      void addNum(String key, TextEditingController c) {
        final v = c.text.trim();
        if (v.isNotEmpty && double.tryParse(v) != null) body[key] = v;
      }
      addNum('height_cm', _heightCtrl);
      addNum('weight_kg', _weightCtrl);
      addNum('temperature_c', _tempCtrl);
      addNum('pulse_bpm', _pulseCtrl);
      if (body.containsKey('pulse_bpm')) {
        body['pulse_bpm'] = int.tryParse(_pulseCtrl.text.trim()) ?? 0;
      }

      await Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))
          .patch('patients/profile/', data: body, options: await _auth());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Health details saved.'),
        backgroundColor: AppColors.accentGreen,
      ));
      _finish();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save. Please try again.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _finish() {
    if (widget.isIntake) {
      context.go('/patient/home');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/patient/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.isIntake,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        title: Text(
          widget.isIntake ? 'Set up your health profile' : 'My Health Details',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: w * 0.042,
            fontWeight: FontWeight.w800,
            color: AppColors.darkBlue900,
          ),
        ),
        actions: [
          if (widget.isIntake)
            TextButton(
              onPressed: _finish,
              child: const Text(
                'Skip for now',
                style: TextStyle(fontFamily: 'Inter', color: AppColors.grey500, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.darkBlue500))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(w * 0.06, 8, w * 0.06, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isIntake) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.sky100.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.favorite_rounded, color: AppColors.sky600, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'These basics help your doctor understand you before a consultation. You can update them any time in your profile.',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, height: 1.45, color: AppColors.darkBlue900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _sectionLabel('Body measurements'),
                  Row(children: [
                    Expanded(child: _numField(_heightCtrl, 'Height', 'cm', decimals: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(_weightCtrl, 'Weight', 'kg', decimals: true)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _numField(_tempCtrl, 'Temperature', '°C', decimals: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(_pulseCtrl, 'Pulse', 'bpm')),
                  ]),
                  const SizedBox(height: 22),
                  _sectionLabel('Blood type'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _bloodTypes.map((t) {
                      final selected = _bloodType == t;
                      return GestureDetector(
                        onTap: () => setState(() => _bloodType = selected ? null : t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.darkBlue500 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selected ? AppColors.darkBlue500 : AppColors.grey200),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: selected ? Colors.white : AppColors.darkBlue900,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  _sectionLabel('Medical background'),
                  _textField(_allergiesCtrl, 'Allergies (comma separated)', 'e.g. Penicillin, peanuts'),
                  const SizedBox(height: 12),
                  _textField(_conditionsCtrl, 'Chronic conditions (comma separated)', 'e.g. Asthma, hypertension'),
                  const SizedBox(height: 12),
                  _textField(_medsCtrl, 'Current medications', 'e.g. Metformin 500 mg daily', maxLines: 2),
                  const SizedBox(height: 22),
                  _sectionLabel('Emergency contact'),
                  _textField(_emergencyNameCtrl, 'Contact name', 'e.g. Marie Dinga'),
                  const SizedBox(height: 12),
                  _textField(_emergencyPhoneCtrl, 'Contact phone', 'e.g. +237 6XX XXX XXX', keyboard: TextInputType.phone),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.darkBlue500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(
                              widget.isIntake ? 'Save & continue' : 'Save changes',
                              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.grey500,
            letterSpacing: 0.3,
          ),
        ),
      );

  InputDecoration _decoration(String label, String hint, {String? suffix}) => InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.grey500),
        hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.grey400),
        filled: true,
        fillColor: AppColors.grey50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.sky500, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _numField(TextEditingController c, String label, String unit, {bool decimals = false}) =>
      TextField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimals),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimals ? r'[\d.]' : r'\d')),
        ],
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w600),
        decoration: _decoration(label, '', suffix: unit),
      );

  Widget _textField(TextEditingController c, String label, String hint,
          {int maxLines = 1, TextInputType? keyboard}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14.5),
        decoration: _decoration(label, hint),
      );
}
