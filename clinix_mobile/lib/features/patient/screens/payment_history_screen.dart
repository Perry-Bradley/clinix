import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../shared/widgets/swipe_to_delete.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});
  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get('${ApiConstants.baseUrl}payments/history/',
        options: Options(headers: {'Authorization': 'Bearer $token'}));
      final data = res.data;
      List items = data is List ? data : (data is Map ? (data['results'] ?? []) : []);
      if (mounted) setState(() { _payments = items.map((e) => Map<String, dynamic>.from(e as Map)).toList(); _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'success': return AppColors.accentGreen;
      case 'failed': return const Color(0xFFEF4444);
      case 'refunded': return AppColors.accentOrange;
      default: return AppColors.grey400;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'success': return Icons.check_circle_rounded;
      case 'failed': return Icons.cancel_rounded;
      case 'refunded': return Icons.replay_rounded;
      default: return Icons.hourglass_top_rounded;
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'mtn_momo': return 'MTN MoMo';
      case 'orange_money': return 'Orange Money';
      case 'cash': return 'Cash';
      default: return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.darkBlue900),
        title: Text('Payment History', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sky500))
          : _payments.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.account_balance_wallet_rounded, size: 56, color: AppColors.grey200),
                  const SizedBox(height: 16),
                  Text('No payments yet', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 4),
                  Text('Your payment history will appear here', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                ]))
              : RefreshIndicator(
                  color: AppColors.sky500,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = _payments[index];
                      final amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
                      final status = p['status']?.toString() ?? 'pending';
                      final method = p['payment_method']?.toString() ?? '';
                      final date = p['initiated_at']?.toString().substring(0, 16).replaceFirst('T', ' ') ?? '';
                      final ref = p['transaction_ref']?.toString() ?? '';
                      final pid = p['payment_id']?.toString() ?? p['id']?.toString() ?? '$index';

                      return SwipeToDeleteCard(
                        dismissibleKey: 'pay-$pid',
                        deletedSnack: 'Hidden from your history',
                        deleteLabel: 'Hide',
                        onDelete: () async {
                          // Payments are financial records — we don't destroy
                          // them on the server, just hide from the local list.
                          if (mounted) setState(() => _payments.removeAt(index));
                          return true;
                        },
                        child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.grey200),
                        ),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_statusIcon(status), color: _statusColor(status), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${amount.toInt()} XAF', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(_methodLabel(method), style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
                            if (ref.isNotEmpty) Text('Ref: ${ref.length > 12 ? '${ref.substring(0, 12)}...' : ref}', style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 10)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status[0].toUpperCase() + status.substring(1),
                                style: AppTextStyles.caption.copyWith(color: _statusColor(status), fontWeight: FontWeight.w700, fontSize: 10)),
                            ),
                            const SizedBox(height: 4),
                            Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 9)),
                          ]),
                        ]),
                      ),
                      );
                    },
                  ),
                ),
    );
  }
}
