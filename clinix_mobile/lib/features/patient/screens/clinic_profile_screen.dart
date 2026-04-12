import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ClinicProfileScreen extends StatefulWidget {
  final String placeId;

  const ClinicProfileScreen({super.key, required this.placeId});

  @override
  State<ClinicProfileScreen> createState() => _ClinicProfileScreenState();
}

class _ClinicProfileScreenState extends State<ClinicProfileScreen> {
  final _dio = Dio();
  final String _apiKey = dotenv.get('GOOGLE_MAPS_API_KEY');
  Map<String, dynamic>? _clinicDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClinicDetails();
  }

  Future<void> _fetchClinicDetails() async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${widget.placeId}'
          '&fields=name,rating,formatted_phone_number,vicinity,opening_hours,website,photos,reviews,user_ratings_total'
          '&key=$_apiKey';

      final response = await _dio.get(url);
      if (response.data['status'] == 'OK') {
        setState(() {
          _clinicDetails = response.data['result'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching place details: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getPhotoUrl(String reference) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$reference&key=$_apiKey';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_clinicDetails == null) {
      return const Scaffold(body: Center(child: Text('Clinic details not found')));
    }

    final photos = _clinicDetails!['photos'] ?? [];
    final reviews = _clinicDetails!['reviews'] ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Elegant Hero Header with Photo
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isNotEmpty
                  ? Image.network(_getPhotoUrl(photos[0]['photo_reference']), fit: BoxFit.cover)
                  : Container(color: AppColors.darkBlue900, child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 80)),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(_clinicDetails!['name'], style: AppTextStyles.headlineLarge)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 20),
                            const SizedBox(width: 4),
                            Text('${_clinicDetails!['rating']}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.accentGreen)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_clinicDetails!['vicinity'] ?? '', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey500)),
                  
                  const SizedBox(height: 24),
                  
                  // Action Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickAction(Icons.phone_rounded, 'Call', () {}),
                      _buildQuickAction(Icons.language_rounded, 'Website', () {}),
                      _buildQuickAction(Icons.share_rounded, 'Share', () {}),
                      _buildQuickAction(Icons.bookmark_outline_rounded, 'Save', () {}),
                    ],
                  ),

                  const Divider(height: 48),

                  // Information Sections
                  _buildInfoSection(Icons.access_time_rounded, 'Business Hours', 
                    _clinicDetails!['opening_hours']?['weekday_text']?.join('\n') ?? 'Hours not available'),
                  
                  const SizedBox(height: 24),

                  _buildInfoSection(Icons.info_outline_rounded, 'About', 
                    'This facility provides comprehensive healthcare services with state-of-the-art equipment and experienced medical staff.'),

                  const Divider(height: 48),

                  // Photos Section (if more than 1)
                  if (photos.length > 1) ...[
                    Text('Photos', style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length - 1,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: Image.network(_getPhotoUrl(photos[index + 1]['photo_reference'])).image,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Reviews
                  Text('Reviews', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 16),
                  ...reviews.map<Widget>((review) => _buildReviewCard(review)).toList(),
                  
                  const SizedBox(height: 40),

                  // Fixed Booking Button at bottom
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.push('/patient/book-appointment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBlue900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Book Appointment Now', style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.grey200)),
          child: Icon(icon, color: AppColors.darkBlue900),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildInfoSection(IconData icon, String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.sky500, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(content, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundImage: NetworkImage(review['profile_photo_url'] ?? '')),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review['author_name'], style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  Text(review['relative_time_description'], style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                ],
              ),
              const Spacer(),
              Row(
                children: List.generate(5, (index) => Icon(Icons.star_rounded, color: index < (review['rating'] ?? 0) ? const Color(0xFFFBBF24) : AppColors.grey400, size: 16)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review['text'], style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
