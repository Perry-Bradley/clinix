import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
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

  @override
  void initState() {
    super.initState();
    _loadNurses();
  }

  Future<void> _loadNurses() async {
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}providers/nearby/',
        queryParameters: {'specialty': 'nurse'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data is List ? res.data : (res.data['results'] ?? []);
      if (mounted) setState(() { _nurses = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
              Center(child: Padding(padding: EdgeInsets.all(w * 0.05), child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.splashSlate900)))
            else if (_nurses.isEmpty)
              Text('No nurses available nearby', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: AppColors.grey400))
            else
              ...(_nurses.take(3).map((n) {
                final name = n['full_name']?.toString() ?? 'Nurse';
                final nurseId = n['provider_id']?.toString() ?? '';
                return Container(
                  margin: EdgeInsets.only(bottom: w * 0.025),
                  padding: EdgeInsets.all(w * 0.035),
                  decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(child: Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, fontWeight: FontWeight.w600, color: AppColors.splashSlate900))),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/dchat/launch/$nurseId?name=${Uri.encodeComponent(name)}');
                        },
                        child: Container(
                          padding: EdgeInsets.all(w * 0.02),
                          decoration: BoxDecoration(color: AppColors.splashSlate900, borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.chat_rounded, color: Colors.white, size: w * 0.04),
                        ),
                      ),
                    ],
                  ),
                );
              })),
            SizedBox(height: w * 0.04),
            SizedBox(
              width: double.infinity,
              height: w * 0.14,
              child: ElevatedButton(
                onPressed: _nurses.isEmpty ? null : () {
                  Navigator.pop(context);
                  context.push('/dchat/launch/${_nurses.first['provider_id']}?name=${Uri.encodeComponent(_nurses.first['full_name'] ?? 'Nurse')}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.splashSlate900,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.grey200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Request This Service', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700)),
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
