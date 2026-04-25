import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final String appointmentId;
  final int consultationFee;

  const PaymentScreen({
    super.key,
    required this.appointmentId,
    this.consultationFee = 15000,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _paymentMethod = 'mtn_momo';
  bool _isProcessing = false;
  String? _errorMessage;
  final TextEditingController _phoneController = TextEditingController(text: '+237');

  Future<void> _processPayment() async {
    if (widget.appointmentId.isEmpty) {
      setState(() => _errorMessage = 'Missing appointment. Go back and try booking again.');
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.length < 9) {
      setState(() => _errorMessage = 'Enter a valid mobile money number (e.g. +237670000000).');
      return;
    }
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final total = widget.consultationFee;
      final payment = await PaymentService.initiate(
        appointmentId: widget.appointmentId,
        paymentMethod: _paymentMethod,
        amount: total.toDouble(),
        payerPhone: phone,
      );
      debugPrint('[Payment] initiate response: $payment');

      final paymentId = payment['payment_id']?.toString();
      final gateway = payment['gateway'];
      if (paymentId == null || paymentId.isEmpty) {
        throw Exception('Missing payment id from server');
      }

      // If the gateway said it could not submit, surface its message right away.
      if (gateway is Map) {
        final configured = gateway['configured'] == true;
        final submitted = gateway['submitted'] == true;
        if (!configured) {
          throw Exception(
            gateway['message']?.toString() ??
                'Payment gateway is not configured. Contact support.',
          );
        }
        if (!submitted) {
          throw Exception(
            'Gateway rejected the request: ${gateway['gateway_response'] ?? 'unknown reason'}',
          );
        }
      }

      // Poll up to ~90 seconds (Campay demo can take a while to auto-approve).
      const maxAttempts = 30; // 30 × 3s = 90s
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        await Future.delayed(const Duration(seconds: 3));
        final statusBody = await PaymentService.getStatus(paymentId);
        final paymentStatus = statusBody['status']?.toString() ?? 'pending';
        debugPrint('[Payment] poll #$attempt status=$paymentStatus');

        if (paymentStatus == 'success') {
          if (mounted) context.pop(true);
          return;
        }
        if (paymentStatus == 'failed' || paymentStatus == 'refunded') {
          throw Exception('Payment was declined.');
        }
      }

      if (mounted) {
        setState(() => _errorMessage =
            'Payment is still pending. Complete the prompt on your phone, then come back to this screen — we\'ll auto-confirm.');
      }
    } catch (e) {
      debugPrint('[Payment] error: $e');
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.consultationFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text('Pay with Mobile Money', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.darkBlue900,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(false),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Consultation Fee', '${widget.consultationFee} XAF', isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Choose provider', style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Clinix checkout uses MTN MoMo and Orange Money for Cameroon.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile money number',
                hintText: '+237677777777',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.grey200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.grey200)),
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentOption(
              id: 'mtn_momo',
              title: 'MTN MoMo',
              subtitle: 'Pay with your MTN Mobile Money wallet',
              icon: Icons.phone_android_rounded,
              accent: const Color(0xFFFFCC00),
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              id: 'orange_money',
              title: 'Orange Money',
              subtitle: 'Pay with Orange Money',
              icon: Icons.account_balance_wallet_rounded,
              accent: Colors.orange,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Pay $total XAF', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? AppColors.darkBlue900 : AppColors.grey500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    final isSelected = _paymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.sky500 : AppColors.grey200, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.sky500.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: AppColors.grey500, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.sky500)
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.grey200, width: 2)),
              ),
          ],
        ),
      ),
    );
  }
}
