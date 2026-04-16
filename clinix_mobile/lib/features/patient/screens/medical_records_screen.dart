import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});
  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get('${ApiConstants.baseUrl}patients/medical-records/',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
      final data = res.data;
      List items = data is List ? data : (data is Map ? (data['results'] ?? []) : []);
      if (mounted) setState(() { _records = items.map((e) => Map<String, dynamic>.from(e as Map)).toList(); _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        title: Text('Medical Records', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
          : _records.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_open_rounded, size: 56, color: AppColors.grey200),
                  const SizedBox(height: 16),
                  Text('No medical records yet', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 4),
                  Text('Records from consultations will appear here', style: AppTextStyles.caption.copyWith(color: AppColors.grey400), textAlign: TextAlign.center),
                ]))
              : RefreshIndicator(
                  color: AppColors.sky500,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = _records[index];
                      final diagnosis = r['diagnosis']?.toString() ?? 'No diagnosis';
                      final treatment = r['treatment_plan']?.toString() ?? '';
                      final symptoms = (r['symptoms'] as List?)?.join(', ') ?? '';
                      final date = r['created_at']?.toString().substring(0, 10) ?? '';
                      final followUp = r['follow_up_date']?.toString();

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
                              decoration: BoxDecoration(color: AppColors.accentCyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.medical_information_rounded, color: AppColors.accentCyan, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(diagnosis, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 11)),
                            ])),
                          ]),
                          if (symptoms.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _InfoRow(label: 'Symptoms', value: symptoms),
                          ],
                          if (treatment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _InfoRow(label: 'Treatment', value: treatment),
                          ],
                          if (followUp != null) ...[
                            const SizedBox(height: 8),
                            _InfoRow(label: 'Follow-up', value: followUp),
                          ],
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey700, fontSize: 13))),
    ]);
  }
}
