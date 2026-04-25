import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';

class LabTestsScreen extends StatefulWidget {
  const LabTestsScreen({super.key});
  @override
  State<LabTestsScreen> createState() => _LabTestsScreenState();
}

class _LabTestsScreenState extends State<LabTestsScreen> {
  String _search = '';
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _tests = [];
  bool _loading = true;

  static const _categories = ['All', 'Blood', 'Urine', 'Imaging', 'STD', 'Other'];

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  Future<void> _fetchTests() async {
    try {
      final res = await Dio().get('${ApiConstants.baseUrl}lab-tests/');
      final data = res.data;
      if (mounted) {
        setState(() {
          _tests = (data is List ? data : []).map<Map<String, dynamic>>((t) {
            return {
              'name': t['name'] ?? '',
              'category': t['category'] ?? 'Other',
              'price': t['price'] ?? 0,
              'turnaround': t['turnaround'] ?? '',
              'sample': t['sample_type'] ?? '',
              'fasting': t['fasting_required'] ?? false,
              'description': t['description'] ?? '',
            };
          }).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _tests.where((t) {
      if (_selectedCategory != 'All' && t['category'] != _selectedCategory) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return (t['name'] as String).toLowerCase().contains(q) || (t['description'] as String).toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

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
        title: Text('Lab Tests', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.045, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: w * 0.02),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.035),
              decoration: InputDecoration(
                hintText: 'Search tests...',
                hintStyle: TextStyle(fontFamily: 'Inter', fontSize: w * 0.035, color: AppColors.grey400),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.grey400, size: w * 0.05),
                filled: true,
                fillColor: AppColors.grey50,
                contentPadding: EdgeInsets.symmetric(vertical: w * 0.032),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          // Category chips
          SizedBox(
            height: w * 0.1,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: w * 0.05),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => SizedBox(width: w * 0.02),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = c == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = c),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.02),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.splashSlate900 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? AppColors.splashSlate900 : AppColors.grey200),
                    ),
                    child: Text(c, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.grey500)),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: w * 0.02),
          // Results count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.05),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_filtered.length} tests available', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.03, color: AppColors.grey400)),
            ),
          ),
          SizedBox(height: w * 0.02),
          // Test list
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: w * 0.05),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => SizedBox(height: w * 0.025),
              itemBuilder: (_, i) => _TestCard(test: _filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final Map<String, dynamic> test;
  const _TestCard({required this.test});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final name = test['name'] as String;
    final price = test['price'] as int;
    final turnaround = test['turnaround'] as String;
    final fasting = test['fasting'] as bool;

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
              child: Icon(Icons.biotech_rounded, color: AppColors.splashSlate900, size: w * 0.055),
            ),
            SizedBox(width: w * 0.035),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, fontWeight: FontWeight.w600, color: AppColors.splashSlate900), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: w * 0.01),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: w * 0.032, color: AppColors.grey400),
                      SizedBox(width: w * 0.01),
                      Text(turnaround, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.028, color: AppColors.grey400)),
                      if (fasting) ...[
                        SizedBox(width: w * 0.03),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.015, vertical: w * 0.005),
                          decoration: BoxDecoration(color: AppColors.accentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text('Fasting', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.024, fontWeight: FontWeight.w600, color: AppColors.accentOrange)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text('$price XAF', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, double w) {
    final name = test['name'] as String;
    final price = test['price'] as int;
    final turnaround = test['turnaround'] as String;
    final sample = test['sample'] as String;
    final fasting = test['fasting'] as bool;
    final description = test['description'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(w * 0.06, w * 0.06, w * 0.06, MediaQuery.of(context).viewInsets.bottom + w * 0.08),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: w * 0.1, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)))),
            SizedBox(height: w * 0.06),
            Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.05, fontWeight: FontWeight.w700, color: AppColors.splashSlate900)),
            SizedBox(height: w * 0.04),
            Text(description, style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.034, color: AppColors.grey500, height: 1.6)),
            SizedBox(height: w * 0.05),
            _DetailRow(label: 'Price', value: '$price XAF', w: w),
            SizedBox(height: w * 0.025),
            _DetailRow(label: 'Turnaround', value: turnaround, w: w),
            SizedBox(height: w * 0.025),
            _DetailRow(label: 'Sample Required', value: sample, w: w),
            SizedBox(height: w * 0.025),
            _DetailRow(label: 'Fasting Required', value: fasting ? 'Yes (8-12 hours)' : 'No', w: w),
            SizedBox(height: w * 0.06),
            SizedBox(
              width: double.infinity,
              height: w * 0.14,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/homecare/book-test', extra: test);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.splashSlate900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Book This Test', style: TextStyle(fontFamily: 'Inter', fontSize: w * 0.038, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final double w;
  const _DetailRow({required this.label, required this.value, required this.w});
  @override
  Widget build(BuildContext context) {
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
