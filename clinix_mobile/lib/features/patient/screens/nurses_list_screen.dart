import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';

/// Browse all nurses, ranked by distance + availability + status. Reached via
/// the "View all nurses" link from the HomeCare and Lab-Test booking flows.
class NursesListScreen extends StatefulWidget {
  const NursesListScreen({super.key});

  @override
  State<NursesListScreen> createState() => _NursesListScreenState();
}

class _NursesListScreenState extends State<NursesListScreen> {
  List<dynamic> _nurses = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
          'limit': 10,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data is List ? res.data : (res.data['results'] ?? []);
      if (mounted) setState(() { _nurses = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load nurses.'; _loading = false; });
    }
  }

  String _location(dynamic n) {
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Nurses near you',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.darkBlue500))
          : _error != null
              ? Center(child: Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)))
              : _nurses.isEmpty
                  ? Center(child: Text('No nurses available right now.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: _nurses.length,
                      itemBuilder: (ctx, i) => _NurseListTile(nurse: _nurses[i], locationLabel: _location(_nurses[i])),
                    ),
    );
  }
}

class _NurseListTile extends StatelessWidget {
  final dynamic nurse;
  final String locationLabel;
  const _NurseListTile({required this.nurse, required this.locationLabel});

  String _initials(String fullName) {
    final cleaned = fullName
        .replaceAll(RegExp(r'^(Nurse|Mr\.?|Mrs\.?|Ms\.?)\s+', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final providerId = nurse['provider_id']?.toString() ?? '';
    final name = nurse['full_name']?.toString() ?? 'Nurse';
    final feeRaw = nurse['consultation_fee']?.toString() ?? '0';
    final fee = double.tryParse(feeRaw)?.toInt() ?? 0;
    final distance = nurse['distance_km'];
    final isOnline = (nurse['status']?.toString() ?? '').toLowerCase() == 'online';
    final ratingValue = double.tryParse(nurse['rating']?.toString() ?? '0') ?? 0;
    final rating = ratingValue.toStringAsFixed(1);

    return GestureDetector(
      onTap: providerId.isEmpty
          ? null
          : () => context.push('/patient/doctor-profile/$providerId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.darkBlue500,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
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
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.darkBlue900,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (isOnline) ...[
                        const SizedBox(width: 6),
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accentGreen, shape: BoxShape.circle)),
                      ],
                    ],
                  ),
                  if (locationLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      distance is num ? '$locationLabel · ${distance.toStringAsFixed(1)} km' : locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 13),
                      const SizedBox(width: 3),
                      Text(rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
                      if (fee > 0) ...[
                        const SizedBox(width: 10),
                        Text(
                          '$fee XAF',
                          style: AppTextStyles.caption.copyWith(color: AppColors.darkBlue500, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
