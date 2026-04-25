import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/doctor_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../widgets/map_location_picker_screen.dart';
import '../widgets/places_autocomplete_field.dart';

/// Provider clinical onboarding: white surface, splash slate accents, real map-based coordinates.
class ProviderEnrollmentScreen extends StatefulWidget {
  const ProviderEnrollmentScreen({super.key});

  @override
  State<ProviderEnrollmentScreen> createState() => _ProviderEnrollmentScreenState();
}

class _ProviderEnrollmentScreenState extends State<ProviderEnrollmentScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Top-level kind: 'doctor' | 'nurse'
  String _providerKind = 'doctor';
  // For doctors: 'generalist' | 'specialist'. For nurses we just store 'nurse'.
  String _doctorRole = 'generalist';
  // Selected admin-configured specialty (only when doctor + specialist).
  Map<String, dynamic>? _selectedSpecialty;
  // Loaded list of available specialties.
  List<Map<String, dynamic>> _specialties = const [];
  bool _loadingSpecialties = false;

  /// Resolved provider_role to send to the backend.
  String get _providerRole {
    if (_providerKind == 'nurse') return 'nurse';
    return _doctorRole; // 'generalist' or 'specialist'
  }

  final _bioCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final Map<String, Map<String, dynamic>> _schedules = {};

  final _residenceAddressCtrl = TextEditingController();
  final _residenceCityCtrl = TextEditingController();
  final _clinicNameCtrl = TextEditingController();
  final _clinicAddressCtrl = TextEditingController();

  double? _resLat;
  double? _resLng;
  double? _clinicLat;
  double? _clinicLng;

  @override
  void initState() {
    super.initState();
    for (final day in _days) {
      _schedules[day] = {
        'is_working': day != 'Saturday' && day != 'Sunday',
        'start_time': '08:00',
        'end_time': '17:00',
      };
    }
  }

  Future<void> _loadSpecialties() async {
    setState(() {
      _loadingSpecialties = true;
      _specialties = const [];
      _selectedSpecialty = null;
    });
    try {
      final res = await Dio().get('${ApiConstants.baseUrl}providers/specialties/');
      final data = res.data;
      if (data is List) {
        _specialties = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      _specialties = const [];
    } finally {
      if (mounted) setState(() => _loadingSpecialties = false);
    }
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _expCtrl.dispose();
    _licenseCtrl.dispose();
    _feeCtrl.dispose();
    _residenceAddressCtrl.dispose();
    _residenceCityCtrl.dispose();
    _clinicNameCtrl.dispose();
    _clinicAddressCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_licenseCtrl.text.trim().isEmpty) {
        _toast('Please enter your medical license number.');
        return;
      }
      if (_bioCtrl.text.trim().isEmpty) {
        _toast('Please add a short professional bio or title.');
        return;
      }
      if (_providerKind == 'doctor' &&
          _doctorRole == 'specialist' &&
          _selectedSpecialty == null) {
        _toast('Please pick your specialty from the list.');
        return;
      }
    }
    if (_currentStep == 2) {
      if (_resLat == null || _resLng == null) {
        _toast('Pin your residence or practice on the map so patients can find you.');
        return;
      }
      if (_residenceAddressCtrl.text.trim().isEmpty) {
        _toast('Add a street address (you can refine text after using the map).');
        return;
      }
      _submitOnboarding();
      return;
    }
    if (_currentStep < 2) setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _openMapPicker({required bool forClinic}) async {
    final initial = forClinic
        ? (_clinicLat != null && _clinicLng != null ? LatLng(_clinicLat!, _clinicLng!) : null)
        : (_resLat != null && _resLng != null ? LatLng(_resLat!, _resLng!) : null);

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          title: forClinic ? 'Clinic / facility location' : 'Primary practice location',
          initialPosition: initial,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final lat = (result['latitude'] as num).toDouble();
    final lng = (result['longitude'] as num).toDouble();
    final formatted = result['formatted_address']?.toString();

    setState(() {
      if (forClinic) {
        _clinicLat = lat;
        _clinicLng = lng;
        if (formatted != null && formatted.isNotEmpty) {
          _clinicAddressCtrl.text = formatted;
        }
      } else {
        _resLat = lat;
        _resLng = lng;
        if (formatted != null && formatted.isNotEmpty) {
          _residenceAddressCtrl.text = formatted;
          final parts = formatted.split(',');
          if (parts.length >= 2) {
            _residenceCityCtrl.text = parts[parts.length - 2].trim();
          }
        }
      }
    });
  }

  Future<void> _submitOnboarding() async {
    setState(() => _isLoading = true);
    try {
      // Map our new role/specialty model into the legacy + new backend fields.
      final legacySpecialty = _providerRole == 'generalist'
          ? 'generalist'
          : (_selectedSpecialty?['name']?.toString() ?? _providerRole);
      await DoctorService.updateProfile({
        'provider_role': _providerRole,
        if (_selectedSpecialty != null) 'specialty_obj': _selectedSpecialty!['specialty_id'],
        'specialty': _providerRole == 'generalist' ? 'generalist' : 'other',
        'other_specialty': _providerRole == 'generalist' ? '' : legacySpecialty,
        'bio': _bioCtrl.text,
        'years_experience': int.tryParse(_expCtrl.text) ?? 1,
        'license_number': _licenseCtrl.text.trim(),
        if (_feeCtrl.text.trim().isNotEmpty)
          'consultation_fee': _feeCtrl.text.trim(),
      });

      final scheduleList = _schedules.entries
          .map((e) => {
                'day': e.key.toLowerCase(),
                'start_time': e.value['start_time'],
                'end_time': e.value['end_time'],
                'is_working': e.value['is_working'],
              })
          .toList();
      await DoctorService.updateSchedule(scheduleList);

      await DoctorService.updateLocation({
        'location_type': 'residence',
        'address': _residenceAddressCtrl.text.trim(),
        'city': _residenceCityCtrl.text.trim(),
        'latitude': _resLat,
        'longitude': _resLng,
      });

      if (_clinicNameCtrl.text.trim().isNotEmpty) {
        await DoctorService.updateLocation({
          'location_type': 'clinic',
          'facility_name': _clinicNameCtrl.text.trim(),
          'address': _clinicAddressCtrl.text.trim().isNotEmpty
              ? _clinicAddressCtrl.text.trim()
              : _residenceAddressCtrl.text.trim(),
          'city': _residenceCityCtrl.text.trim(),
          'latitude': _clinicLat ?? _resLat,
          'longitude': _clinicLng ?? _resLng,
        });
      }

      if (mounted) context.go('/provider/home');
    } catch (e) {
      if (mounted) _toast('Could not save profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.splashSlate900,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Provider setup',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.splashSlate900,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: _currentStep > 0
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _prevStep)
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.grey200),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: _StepHeader(current: _currentStep, accent: AppColors.splashSlate900),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _buildCurrentStepView(),
            ),
          ),
          _buildBottomCta(),
        ],
      ),
    );
  }

  Widget _buildBottomCta() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _isLoading ? null : _nextStep,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.splashSlate900,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _currentStep == 2 ? 'Complete & go to dashboard' : 'Continue',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStepProfile();
      case 1:
        return _buildStepSchedule();
      case 2:
        return _buildStepLocations();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional profile',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.splashSlate900,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Patients see this when they browse providers.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, height: 1.4),
        ),
        const SizedBox(height: 24),
        _fieldLabel('Are you a doctor or a nurse?'),
        const SizedBox(height: 6),
        _kindSelector(),
        if (_providerKind == 'doctor') ...[
          const SizedBox(height: 18),
          _fieldLabel('Doctor type'),
          const SizedBox(height: 6),
          _doctorTypeSelector(),
          if (_doctorRole == 'specialist') ...[
            const SizedBox(height: 18),
            _fieldLabel('Pick your specialty'),
            const SizedBox(height: 6),
            _specialtyDropdown(),
          ],
        ],
        const SizedBox(height: 20),
        _fieldLabel('Medical license number *'),
        _textField(_licenseCtrl, 'e.g. CM-MED-2019-0451', lines: 1),
        const SizedBox(height: 20),
        _fieldLabel('Years of experience'),
        _textField(_expCtrl, 'e.g. 5', keyboard: TextInputType.number),
        const SizedBox(height: 20),
        _fieldLabel('Consultation fee (XAF)'),
        _textField(_feeCtrl, 'e.g. 15000', keyboard: TextInputType.number),
        const SizedBox(height: 20),
        _fieldLabel('Professional bio'),
        _textField(_bioCtrl, 'Training, focus areas, languages spoken…', lines: 5),
      ],
    );
  }

  Widget _buildStepSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Availability',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.splashSlate900,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Used to generate booking slots.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
        ),
        const SizedBox(height: 20),
        ..._days.map(_scheduleRow),
      ],
    );
  }

  Widget _scheduleRow(String day) {
    final isWorking = _schedules[day]!['is_working'] as bool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: isWorking,
                activeColor: AppColors.sky600,
                onChanged: (v) => setState(() => _schedules[day]!['is_working'] = v ?? false),
              ),
              Expanded(
                child: Text(
                  day,
                  style: TextStyle(
                    color: AppColors.splashSlate900,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isWorking) ...[
                _timeChip(day, true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: AppColors.grey500)),
                ),
                _timeChip(day, false),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeChip(String day, bool isStart) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _selectTime(day, isStart),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            _schedules[day]![isStart ? 'start_time' : 'end_time'].toString(),
            style: TextStyle(
              color: AppColors.sky600,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepLocations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Locations on the map',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.splashSlate900,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'We use your coordinates to match nearby patients. Google Maps picks an accurate pin.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, height: 1.45),
        ),
        const SizedBox(height: 20),
        _locationCard(
          title: 'Primary location (required)',
          subtitle: 'Residence or main practice — used for distance search.',
          lat: _resLat,
          lng: _resLng,
          onPickMap: () => _openMapPicker(forClinic: false),
        ),
        const SizedBox(height: 16),
        PlacesAutocompleteField(
          controller: _residenceAddressCtrl,
          hint: 'Type your practice address',
          onSelected: (address, lat, lng) {
            setState(() {
              if (lat != null) _resLat = lat;
              if (lng != null) _resLng = lng;
              final parts = address.split(',');
              if (parts.length >= 2) _residenceCityCtrl.text = parts[parts.length - 2].trim();
            });
          },
        ),
        const SizedBox(height: 12),
        _textField(_residenceCityCtrl, 'City / region'),
        const SizedBox(height: 28),
        Text(
          'Facility (optional)',
          style: TextStyle(
            color: AppColors.splashSlate900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _textField(_clinicNameCtrl, 'Hospital or clinic name'),
        const SizedBox(height: 12),
        _locationCard(
          title: 'Facility map pin (optional)',
          subtitle: 'If different from your primary location.',
          lat: _clinicLat,
          lng: _clinicLng,
          onPickMap: () => _openMapPicker(forClinic: true),
        ),
        const SizedBox(height: 12),
        PlacesAutocompleteField(
          controller: _clinicAddressCtrl,
          hint: 'Type clinic / facility address',
          onSelected: (address, lat, lng) {
            setState(() {
              if (lat != null) _clinicLat = lat;
              if (lng != null) _clinicLng = lng;
            });
          },
        ),
      ],
    );
  }

  Widget _locationCard({
    required String title,
    required String subtitle,
    required double? lat,
    required double? lng,
    required VoidCallback onPickMap,
  }) {
    final has = lat != null && lng != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: has ? AppColors.sky200 : AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.splashSlate900)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.grey500, height: 1.35)),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                has ? Icons.check_circle_rounded : Icons.location_searching_rounded,
                color: has ? AppColors.accentGreen : AppColors.sky600,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  has
                      ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                      : 'No pin yet — open the map',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: has ? AppColors.grey700 : AppColors.grey500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPickMap,
            icon: const Icon(Icons.map_rounded, size: 20),
            label: Text(has ? 'Adjust on map' : 'Choose on Google Map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.splashSlate900,
              side: BorderSide(color: AppColors.splashSlate900.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.splashSlate900,
        ),
      ),
    );
  }

  Widget _kindSelector() {
    final kinds = [
      {
        'key': 'doctor',
        'label': 'Doctor',
        'sub': 'Generalist or specialist',
        'icon': Icons.local_hospital_rounded,
      },
      {
        'key': 'nurse',
        'label': 'Nurse',
        'sub': 'Nursing professional',
        'icon': Icons.health_and_safety_rounded,
      },
    ];
    return Row(
      children: kinds.map((k) {
        final selected = _providerKind == k['key'];
        final isLast = k['key'] == kinds.last['key'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _providerKind = k['key']! as String;
                  _selectedSpecialty = null;
                  _specialties = const [];
                  // Reset doctor role on kind switch.
                  if (_providerKind == 'nurse') {
                    _doctorRole = 'generalist';
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
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
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withOpacity(0.15) : AppColors.sky100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        k['icon'] as IconData,
                        color: selected ? Colors.white : AppColors.darkBlue800,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      k['label']! as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: selected ? Colors.white : AppColors.darkBlue900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      k['sub']! as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: selected
                            ? Colors.white.withOpacity(0.85)
                            : AppColors.grey500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _doctorTypeSelector() {
    const types = [
      {'key': 'generalist', 'label': 'Generalist', 'sub': 'General medicine'},
      {'key': 'specialist', 'label': 'Specialist', 'sub': 'Choose specialty'},
    ];
    return Row(
      children: types.map((t) {
        final selected = _doctorRole == t['key'];
        final isLast = t['key'] == types.last['key'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: GestureDetector(
              onTap: () {
                setState(() => _doctorRole = t['key']!);
                if (t['key'] == 'specialist') {
                  _loadSpecialties();
                } else {
                  setState(() {
                    _selectedSpecialty = null;
                    _specialties = const [];
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.darkBlue800 : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.darkBlue800 : AppColors.grey200,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      t['label']!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: selected ? Colors.white : AppColors.darkBlue900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t['sub']!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: selected
                            ? Colors.white.withOpacity(0.85)
                            : AppColors.grey500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _specialtyDropdown() {
    if (_loadingSpecialties) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Loading…',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
          ],
        ),
      );
    }
    if (_specialties.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFEDD5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFC2410C), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No options yet — please ask the admin to configure specialties.',
                style: AppTextStyles.caption.copyWith(color: const Color(0xFF9A3412)),
              ),
            ),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedSpecialty?['specialty_id']?.toString(),
      decoration: _decoration('Pick a specialty'),
      items: _specialties
          .map((s) => DropdownMenuItem<String>(
                value: s['specialty_id']?.toString(),
                child: Text(s['name']?.toString() ?? ''),
              ))
          .toList(),
      onChanged: (v) {
        setState(() {
          _selectedSpecialty = _specialties.firstWhere(
            (s) => s['specialty_id']?.toString() == v,
            orElse: () => const {},
          );
          if (_selectedSpecialty?.isEmpty ?? true) _selectedSpecialty = null;
        });
      },
      style: TextStyle(color: AppColors.splashSlate900, fontWeight: FontWeight.w600),
      dropdownColor: Colors.white,
      iconEnabledColor: AppColors.grey500,
    );
  }

  Widget _textField(
    TextEditingController c,
    String hint, {
    int lines = 1,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c,
      maxLines: lines,
      keyboardType: keyboard,
      style: TextStyle(color: AppColors.splashSlate900, fontSize: 15),
      decoration: _decoration(hint),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.grey400, fontSize: 14),
      filled: true,
      fillColor: AppColors.grey50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.grey200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.grey200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sky500, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _selectTime(String day, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _schedules[day]![isStart ? 'start_time' : 'end_time'] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }
}

class _StepHeader extends StatelessWidget {
  final int current;
  final Color accent;

  const _StepHeader({required this.current, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final done = i < current;
        final active = i == current;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      decoration: BoxDecoration(
                        color: done || active ? accent : AppColors.grey200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ['Profile', 'Schedule', 'Location'][i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? accent : AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 2) const SizedBox(width: 8),
            ],
          ),
        );
      }),
    );
  }
}
