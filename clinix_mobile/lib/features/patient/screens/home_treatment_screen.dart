import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

class HomeTreatmentScreen extends StatelessWidget {
  const HomeTreatmentScreen({super.key});

  static const List<Map<String, dynamic>> _treatments = [
    {
      'icon': Icons.vaccines_rounded,
      'title': 'Administer Medication',
      'subtitle': 'IV drips, injections, medication given by a nurse at home',
      'details': 'A qualified nurse visits your home to administer prescribed medication — IV infusions, intramuscular injections, subcutaneous injections, or supervised oral medication. Ideal for patients who need hospital-level treatment from the comfort of home.',
      'price': 10000,
      'duration': '1-2 hours',
    },
    {
      'icon': Icons.healing_rounded,
      'title': 'Wound Treatment',
      'subtitle': 'Wound cleaning, dressing changes, and post-surgery care',
      'details': 'Professional wound care at home — cleaning, debridement, dressing changes, suture removal, and post-operative wound management. Reduces infection risk and hospital visits.',
      'price': 8000,
      'duration': '30-60 min',
    },
    {
      'icon': Icons.monitor_heart_rounded,
      'title': 'Vital Signs Monitoring',
      'subtitle': 'Blood pressure, temperature, oxygen, blood sugar checks',
      'details': 'Regular monitoring of vital signs for patients with chronic conditions — hypertension, diabetes, heart disease. Includes blood pressure, pulse, temperature, SpO2, and blood glucose measurement.',
      'price': 5000,
      'duration': '30 min',
    },
    {
      'icon': Icons.baby_changing_station_rounded,
      'title': 'Post-Natal Care',
      'subtitle': 'Mother and newborn check-ups, breastfeeding support',
      'details': 'Home visits for new mothers — baby weight monitoring, umbilical cord care, breastfeeding guidance, maternal recovery assessment, and vaccination scheduling.',
      'price': 12000,
      'duration': '1-2 hours',
    },
    {
      'icon': Icons.elderly_rounded,
      'title': 'Elderly Care',
      'subtitle': 'Daily care, medication management, mobility assistance',
      'details': 'Dedicated nursing care for elderly family members — medication reminders, hygiene assistance, mobility support, companionship, and health monitoring.',
      'price': 15000,
      'duration': '4-8 hours',
    },
    {
      'icon': Icons.air_rounded,
      'title': 'Nebulization / Oxygen',
      'subtitle': 'Respiratory therapy and oxygen administration at home',
      'details': 'Home respiratory care — nebulizer treatments for asthma or respiratory infections, oxygen therapy setup and monitoring for patients requiring supplemental oxygen.',
      'price': 8000,
      'duration': '30-60 min',
    },
  ];

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
        title: Text('Home Treatment', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700)),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(w * 0.05),
        itemCount: _treatments.length,
        separatorBuilder: (_, __) => SizedBox(height: w * 0.03),
        itemBuilder: (_, i) => _TreatmentCard(treatment: _treatments[i]),
      ),
    );
  }
}

class _TreatmentCard extends StatelessWidget {
  final Map<String, dynamic> treatment;
  const _TreatmentCard({required this.treatment});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () => _showDetail(context, w),
      child: Container(
        padding: EdgeInsets.all(w * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(w * 0.03),
              decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(12)),
              child: Icon(treatment['icon'] as IconData, color: AppColors.splashSlate900, size: w * 0.06),
            ),
            SizedBox(width: w * 0.035),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(treatment['title'] as String, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.035, fontWeight: FontWeight.w600, color: AppColors.splashSlate900)),
                  SizedBox(height: w * 0.008),
                  Text(treatment['subtitle'] as String, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: AppColors.grey500, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: w * 0.035, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, double w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TreatmentDetailSheet(treatment: treatment),
    );
  }
}

class _TreatmentDetailSheet extends StatefulWidget {
  final Map<String, dynamic> treatment;
  const _TreatmentDetailSheet({required this.treatment});
  @override
  State<_TreatmentDetailSheet> createState() => _TreatmentDetailSheetState();
}

class _TreatmentDetailSheetState extends State<_TreatmentDetailSheet> {
  List<dynamic> _nurses = [];
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _selectedNurse;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '09:00';
  final TextEditingController _addressCtrl = TextEditingController();

  static const _timeSlots = ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNurses();
  }

  Future<void> _loadNurses() async {
    try {
      double? lat;
      double? lng;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}providers/recommended/',
        queryParameters: {
          'role': 'nurse',
          'limit': 3,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data is List ? res.data : (res.data['results'] ?? []);
      if (mounted) setState(() { _nurses = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _canBook() {
    final nurseId = _selectedNurse?['provider_id']?.toString() ?? '';
    return nurseId.isNotEmpty && _addressCtrl.text.trim().isNotEmpty;
  }

  void _payAndBook(int price) {
    final nurseId = _selectedNurse!['provider_id'].toString();
    final timeParts = _selectedTime.split(':');
    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.tryParse(timeParts[0]) ?? 9,
      timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0,
    );
    final title = widget.treatment['title'] as String;
    final address = _addressCtrl.text.trim();

    Navigator.pop(context);
    context.push('/patient/payment', extra: {
      'consultationFee': price,
      'summaryLabel': title,
      'pendingBooking': {
        'provider_id': nurseId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'appointment_type': 'home_treatment',
        'address': address,
        'service_name': title,
        'duration_minutes': 60,
      },
    });
  }

  String _nurseLocation(dynamic n) {
    final locs = n['locations'];
    if (locs is List && locs.isNotEmpty && locs.first is Map) {
      final m = locs.first as Map;
      final city = m['city']?.toString().trim() ?? '';
      final region = m['region']?.toString().trim() ?? '';
      return [city, region].where((s) => s.isNotEmpty).join(', ');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final t = widget.treatment;
    final price = t['price'] as int;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.fromLTRB(w * 0.06, w * 0.06, w * 0.06, w * 0.08),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: w * 0.1, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)))),
            SizedBox(height: w * 0.06),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(w * 0.035),
                  decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14)),
                  child: Icon(t['icon'] as IconData, color: AppColors.splashSlate900, size: w * 0.07),
                ),
                SizedBox(width: w * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'] as String, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                      SizedBox(height: w * 0.01),
                      Text('From $price XAF', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, fontWeight: FontWeight.w600, color: AppColors.grey500)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: w * 0.05),
            Text(t['details'] as String, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.033, color: AppColors.grey500, height: 1.6)),
            SizedBox(height: w * 0.04),
            _infoRow('Duration', t['duration'] as String, w),
            SizedBox(height: w * 0.02),
            _infoRow('Starting Price', '$price XAF', w),
            SizedBox(height: w * 0.05),
            Text('Available Nurses', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
            SizedBox(height: w * 0.03),
            if (_loading)
              Center(child: Padding(padding: EdgeInsets.all(w * 0.05), child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.darkBlue500)))
            else if (_nurses.isEmpty)
              Text('No nurses available nearby', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: AppColors.grey400))
            else ...[
              ..._nurses.take(3).map((n) {
                final name = n['full_name']?.toString() ?? 'Nurse';
                final nurseId = n['provider_id']?.toString() ?? '';
                final feeRaw = n['consultation_fee']?.toString() ?? '0';
                final fee = double.tryParse(feeRaw)?.toInt() ?? 0;
                final distance = n['distance_km'];
                final location = _nurseLocation(n);
                final isOnline = (n['status']?.toString() ?? '').toLowerCase() == 'online';
                final isSelected = _selectedNurse?['provider_id']?.toString() == nurseId;

                return GestureDetector(
                  onTap: () => setState(() => _selectedNurse = Map<String, dynamic>.from(n)),
                  child: Container(
                    margin: EdgeInsets.only(bottom: w * 0.025),
                    padding: EdgeInsets.all(w * 0.035),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.darkBlue500 : AppColors.grey200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isSelected)
                          Padding(
                            padding: EdgeInsets.only(right: w * 0.025),
                            child: Container(
                              width: 18, height: 18,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(color: AppColors.darkBlue500, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.035, fontWeight: FontWeight.w800, color: AppColors.darkBlue900),
                                    ),
                                  ),
                                  if (isOnline) ...[
                                    SizedBox(width: w * 0.018),
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle)),
                                  ],
                                ],
                              ),
                              if (location.isNotEmpty) ...[
                                SizedBox(height: w * 0.005),
                                Text(
                                  distance is num ? '$location · ${distance.toStringAsFixed(1)} km' : location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.026, color: AppColors.grey500),
                                ),
                              ],
                              SizedBox(height: w * 0.008),
                              Text(
                                fee > 0 ? '$fee XAF' : 'Fee on request',
                                style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, fontWeight: FontWeight.w700, color: AppColors.darkBlue500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/patient/nurses');
                },
                child: Padding(
                  padding: EdgeInsets.only(top: w * 0.005, bottom: w * 0.01),
                  child: Row(
                    children: [
                      Text(
                        'View all nurses',
                        style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, fontWeight: FontWeight.w700, color: AppColors.darkBlue500),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.darkBlue500),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: w * 0.05),
            // ── Schedule + address ──
            Text('Your Address', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
            SizedBox(height: w * 0.02),
            TextField(
              controller: _addressCtrl,
              style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034),
              decoration: InputDecoration(
                hintText: 'Where should the nurse come?',
                hintStyle: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, color: AppColors.grey400),
                filled: true,
                fillColor: AppColors.grey50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),

            SizedBox(height: w * 0.04),
            Text('Preferred Date', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
            SizedBox(height: w * 0.02),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.035),
                decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: AppColors.darkBlue500, size: w * 0.05),
                    SizedBox(width: w * 0.03),
                    Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.036, fontWeight: FontWeight.w600, color: AppColors.darkBlue900)),
                  ],
                ),
              ),
            ),

            SizedBox(height: w * 0.04),
            Text('Preferred Time', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
            SizedBox(height: w * 0.02),
            Wrap(
              spacing: w * 0.025,
              runSpacing: w * 0.025,
              children: _timeSlots.map((t) {
                final sel = t == _selectedTime;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTime = t),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.025),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.darkBlue500 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? AppColors.darkBlue500 : AppColors.grey200),
                    ),
                    child: Text(t, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.grey700)),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: w * 0.06),
            SizedBox(
              width: double.infinity,
              height: w * 0.14,
              child: ElevatedButton(
                onPressed: _canBook() ? () => _payAndBook(price) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue500,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.grey200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Pay & Book ($price XAF)', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, double w) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.03),
      decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: AppColors.grey500)),
          Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, fontWeight: FontWeight.w600, color: AppColors.splashSlate900)),
        ],
      ),
    );
  }
}
