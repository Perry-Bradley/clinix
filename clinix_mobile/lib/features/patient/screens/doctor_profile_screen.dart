import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String providerId;
  const DoctorProfileScreen({super.key, required this.providerId});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final Dio _dio = Dio();
  dynamic _provider;
  List<Map<String, dynamic>> _reviews = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProviderDetails();
  }

  Future<void> _fetchReviews() async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.providers}${widget.providerId}/reviews/',
      );
      if (!mounted) return;
      final data = response.data;
      setState(() {
        _reviews = data is List ? List<Map<String, dynamic>>.from(data) : const [];
      });
    } catch (_) {}
  }

  Future<void> _fetchProviderDetails() async {
    try {
      final token = await AuthService.getAccessToken();
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.providers}${widget.providerId}/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        setState(() {
          if (response.data is Map) {
            _provider = response.data;
          } else {
            _provider = null;
            _error = 'Unexpected data format from server.';
          }
          _isLoading = false;
        });
      }
      await _fetchReviews();
    } catch (e) {
      if (mounted) {
        setState(() {
          _provider = null;
          _isLoading = false;
          _error = 'Could not load doctor profile.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null || _provider == null || _provider is! Map) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: AppColors.darkBlue900)),
        body: Center(child: Text(_error ?? 'Doctor not found')),
      );
    }

    final name = _provider['full_name']?.toString() ?? 'Doctor';
    final spec = (_provider['other_specialty']?.toString().trim().isNotEmpty ?? false)
        ? _provider['other_specialty'].toString()
        : (_provider['specialty']?.toString() ?? 'General Practitioner');
    final rawBio = (_provider['bio'] ?? '').toString();
    final bioText = rawBio.isNotEmpty ? rawBio : 'Dedicated healthcare professional focusing on patient-centered care and modern medical practices.';
    final bio = 'As a $spec, $bioText';
    final rating = (double.tryParse(_provider['rating']?.toString() ?? '') ?? 0.0).toStringAsFixed(1);
    final reviewsCount = _provider['review_count'] ?? _provider['reviews_count'] ?? 0;
    final yearsExp = _provider['years_experience'] ?? 0;
    final fee = _provider['consultation_fee']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 190,
            backgroundColor: AppColors.darkBlue900,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineLarge.copyWith(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(spec, style: AppTextStyles.caption.copyWith(color: AppColors.sky200, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                            const SizedBox(width: 3),
                            Text(rating, style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800, fontSize: 12)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(label: 'Consults', value: '${_provider['total_consultations'] ?? 0}'),
                    _StatItem(label: 'Experience', value: '$yearsExp YRS'),
                    _StatItem(label: 'Fee', value: '$fee XAF'),
                  ],
                ),
                const SizedBox(height: 32),
                Text('Biography', style: AppTextStyles.headlineSmall),
                const SizedBox(height: 8),
                Text(bio, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, height: 1.6)),
                const SizedBox(height: 32),

                // Reviews Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Patient Reviews', style: AppTextStyles.headlineSmall),
                    TextButton(
                      onPressed: () => _showReviewModal(context),
                      child: Text('Write a Review', style: TextStyle(color: AppColors.sky600, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_reviews.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
                    child: Text('No patient reviews yet.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
                  )
                else
                  ..._reviews.map((r) => _ReviewCard(review: {
                    'name': r['patient_name'] ?? 'Patient',
                    'rating': r['rating'] ?? 0,
                    'comment': r['comment'] ?? '',
                    'date': r['created_at']?.toString() ?? '',
                  })),

                const SizedBox(height: 32),
                Text('Location', style: AppTextStyles.headlineSmall),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.sky100, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.location_on_rounded, color: AppColors.sky600),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((_provider['locations'] is List && (_provider['locations'] as List).isNotEmpty)
                                ? (((_provider['locations'] as List).first['facility_name'] ?? 'Clinic').toString())
                                : 'Clinic location unavailable', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text((_provider['locations'] is List && (_provider['locations'] as List).isNotEmpty)
                                ? ('${((_provider['locations'] as List).first['city'] ?? '').toString()}, ${((_provider['locations'] as List).first['region'] ?? '').toString()}')
                                : 'Location unavailable', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 120), // Space for bottom button
              ]),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: () => context.push('/patient/book-appointment', extra: _provider),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.sky600,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: const Text('Book Appointment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showReviewModal(BuildContext context) {
    final providerName = _provider?['full_name']?.toString() ?? 'Doctor';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReviewSubmissionModal(
        providerId: widget.providerId,
        providerName: providerName,
        onSubmitted: () async {
          // Re-fetch both reviews AND provider data (rating updates server-side)
          await _fetchProviderDetails();
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.headlineSmall);
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(review['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < review['rating'] ? const Color(0xFFFBBF24) : AppColors.grey200)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review['comment'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 8),
          Text(review['date'], style: AppTextStyles.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ReviewSubmissionModal extends StatefulWidget {
  final String providerId;
  final String providerName;
  final Future<void> Function() onSubmitted;
  const _ReviewSubmissionModal({required this.providerId, required this.providerName, required this.onSubmitted});
  @override
  State<_ReviewSubmissionModal> createState() => _ReviewSubmissionModalState();
}

class _ReviewSubmissionModalState extends State<_ReviewSubmissionModal> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text('How was your visit with ${widget.providerName}?', textAlign: TextAlign.center, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(Icons.star_rounded, size: 40, color: i < _rating ? const Color(0xFFFBBF24) : AppColors.grey200),
              onPressed: () => setState(() => _rating = i + 1),
            )),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting || _rating == 0 ? null : () async {
              setState(() => _submitting = true);
              try {
                final token = await AuthService.getAccessToken();
                await Dio().post(
                  '${ApiConstants.baseUrl}${ApiConstants.providers}${widget.providerId}/reviews/',
                  data: {
                    'rating': _rating,
                    'comment': _commentController.text.trim(),
                  },
                  options: Options(headers: {'Authorization': 'Bearer $token'}),
                );
                if (!mounted) return;
                Navigator.pop(context);
                await widget.onSubmitted();
              } finally {
                if (mounted) setState(() => _submitting = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sky600,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.headlineSmall.copyWith(color: AppColors.sky600)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
