import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

class BookLabTestScreen extends StatefulWidget {
  final Map<String, dynamic> test;
  const BookLabTestScreen({super.key, required this.test});
  @override
  State<BookLabTestScreen> createState() => _BookLabTestScreenState();
}

class _BookLabTestScreenState extends State<BookLabTestScreen> {
  List<dynamic> _nurses = [];
  bool _loading = true;
  Map<String, dynamic>? _selectedNurse;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '09:00';
  String _address = '';
  final _addressCtrl = TextEditingController();

  static const _timeSlots = ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];

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
    final test = widget.test;
    final testName = test['name'] as String;
    final price = test['price'] as int;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.splashSlate900,
        surfaceTintColor: Colors.transparent,
        title: Text('Book Test', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.splashSlate900))
          : SingleChildScrollView(
              padding: EdgeInsets.all(w * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Test summary
                  Container(
                    padding: EdgeInsets.all(w * 0.04),
                    decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.biotech_rounded, color: AppColors.splashSlate900, size: w * 0.06),
                        SizedBox(width: w * 0.03),
                        Expanded(child: Text(testName, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.036, fontWeight: FontWeight.w600, color: AppColors.splashSlate900))),
                        Text('$price XAF', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.036, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
                      ],
                    ),
                  ),

                  SizedBox(height: w * 0.06),
                  _sectionTitle('Select a Nurse', w),
                  SizedBox(height: w * 0.03),

                  if (_nurses.isEmpty)
                    Container(
                      padding: EdgeInsets.all(w * 0.05),
                      decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(14)),
                      child: Center(child: Text('No nurses available in your area', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, color: AppColors.grey400))),
                    )
                  else
                    ...(_nurses.map((n) => _NurseCard(
                      nurse: n,
                      selected: _selectedNurse?['provider_id'] == n['provider_id'],
                      onTap: () => setState(() => _selectedNurse = Map<String, dynamic>.from(n)),
                      onMessage: () => context.push('/dchat/launch/${n['provider_id']}?name=${Uri.encodeComponent(n['full_name'] ?? 'Nurse')}'),
                    ))),

                  SizedBox(height: w * 0.06),
                  _sectionTitle('Your Address', w),
                  SizedBox(height: w * 0.02),
                  TextField(
                    controller: _addressCtrl,
                    onChanged: (v) => _address = v,
                    style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034),
                    decoration: InputDecoration(
                      hintText: 'Where should the nurse come?',
                      hintStyle: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, color: AppColors.grey400),
                      filled: true,
                      fillColor: AppColors.grey50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),

                  SizedBox(height: w * 0.06),
                  _sectionTitle('Preferred Date', w),
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
                          Icon(Icons.calendar_today_rounded, color: AppColors.splashSlate900, size: w * 0.05),
                          SizedBox(width: w * 0.03),
                          Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.036, fontWeight: FontWeight.w600, color: AppColors.splashSlate900)),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: w * 0.06),
                  _sectionTitle('Preferred Time', w),
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
                            color: sel ? AppColors.splashSlate900 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sel ? AppColors.splashSlate900 : AppColors.grey200),
                          ),
                          child: Text(t, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.grey500)),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: w * 0.08),

                  // Checkout summary
                  Container(
                    padding: EdgeInsets.all(w * 0.04),
                    decoration: BoxDecoration(color: AppColors.splashSlate900, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        _summaryRow('Lab Test', '$price XAF', w),
                        SizedBox(height: w * 0.02),
                        _summaryRow('Sample Collection Fee', '2000 XAF', w),
                        Divider(color: Colors.white24, height: w * 0.05),
                        _summaryRow('Total', '${price + 2000} XAF', w, bold: true),
                      ],
                    ),
                  ),

                  SizedBox(height: w * 0.04),

                  SizedBox(
                    width: double.infinity,
                    height: w * 0.14,
                    child: ElevatedButton(
                      onPressed: (_selectedNurse != null && _address.isNotEmpty) ? () {
                        context.push('/patient/payment', extra: {
                          'amount': price + 2000,
                          'description': 'Lab Test: $testName',
                          'provider': _selectedNurse,
                        });
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.splashSlate900,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.grey200,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text('Proceed to Payment', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(height: w * 0.06),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text, double w) => Text(text, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.04, fontWeight: FontWeight.w700, color: AppColors.splashSlate900));

  Widget _summaryRow(String label, String value, double w, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.032, color: bold ? Colors.white : Colors.white60)),
        Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: Colors.white)),
      ],
    );
  }
}

class _NurseCard extends StatelessWidget {
  final dynamic nurse;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onMessage;
  const _NurseCard({required this.nurse, required this.selected, required this.onTap, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final name = nurse['full_name']?.toString() ?? 'Nurse';
    final rating = (double.tryParse(nurse['rating']?.toString() ?? '') ?? 0).toStringAsFixed(1);
    final fee = nurse['consultation_fee']?.toString() ?? '0';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: w * 0.025),
        padding: EdgeInsets.all(w * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.splashSlate900 : AppColors.grey200, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            if (selected)
              Container(
                padding: EdgeInsets.all(w * 0.01),
                margin: EdgeInsets.only(right: w * 0.03),
                decoration: BoxDecoration(color: AppColors.splashSlate900, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: Colors.white, size: w * 0.035),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.035, fontWeight: FontWeight.w600, color: AppColors.splashSlate900)),
                  SizedBox(height: w * 0.008),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: w * 0.035, color: const Color(0xFFFBBF24)),
                      SizedBox(width: w * 0.01),
                      Text(rating, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, fontWeight: FontWeight.w600, color: AppColors.grey500)),
                      SizedBox(width: w * 0.04),
                      Text('$fee XAF', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: AppColors.grey400)),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onMessage,
              child: Container(
                padding: EdgeInsets.all(w * 0.025),
                decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.chat_rounded, color: AppColors.splashSlate900, size: w * 0.045),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
