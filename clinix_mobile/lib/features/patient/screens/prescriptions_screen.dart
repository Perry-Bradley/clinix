import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});
  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get('${ApiConstants.baseUrl}patients/prescriptions/',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
      final data = res.data;
      List items = data is List ? data : (data is Map ? (data['results'] ?? []) : []);
      if (mounted) setState(() { _prescriptions = items.map((e) => Map<String, dynamic>.from(e as Map)).toList(); _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        title: Text('Prescriptions', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
          : _prescriptions.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_rounded, size: 56, color: AppColors.grey200),
                  const SizedBox(height: 16),
                  Text('No prescriptions yet', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 4),
                  Text('Prescriptions from your consultations will appear here', style: AppTextStyles.caption.copyWith(color: AppColors.grey400), textAlign: TextAlign.center),
                ]))
              : RefreshIndicator(
                  color: AppColors.sky500,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _prescriptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = _prescriptions[index];
                      final meds = (p['medications'] as List?) ?? [];
                      final date = p['issued_at']?.toString().substring(0, 10) ?? '';
                      final providerName = p['provider_name']?.toString() ?? p['provider']?.toString() ?? 'Doctor';
                      final isValid = p['valid_until'] != null && DateTime.tryParse(p['valid_until'].toString())?.isAfter(DateTime.now()) == true;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.grey200),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.sky100, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.medication_rounded, color: AppColors.sky500, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Prescription', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text('By $providerName', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isValid ? AppColors.accentGreen.withValues(alpha: 0.1) : AppColors.grey100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(isValid ? 'Active' : 'Expired',
                                style: AppTextStyles.caption.copyWith(color: isValid ? AppColors.accentGreen : AppColors.grey400, fontWeight: FontWeight.w700, fontSize: 10)),
                            ),
                          ]),
                          if (meds.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            ...meds.map((m) {
                              final med = m is Map ? m : {};
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.sky500, shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(med['name']?.toString() ?? 'Medication', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                                    Text('${med['dosage'] ?? ''} - ${med['frequency'] ?? ''} - ${med['duration'] ?? ''}',
                                      style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 11)),
                                  ])),
                                ]),
                              );
                            }),
                          ],
                          if (p['instructions'] != null && p['instructions'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(10)),
                              child: Text(p['instructions'].toString(), style: AppTextStyles.caption.copyWith(color: AppColors.grey500, height: 1.4)),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 10)),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
