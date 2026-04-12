import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

class DoctorsListScreen extends StatefulWidget {
  const DoctorsListScreen({super.key});

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
  static final String _baseUrl = 'providers/nearby/';

  List<dynamic> _doctors = [];
  bool _isLoading = true;
  String? _error;
  
  dynamic _selectedDoctor;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }


  Future<void> _loadDoctors() async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        _currentPosition = position;
      } catch (e) {
        print('Error getting location: $e');
      }

      final token = await AuthService.getAccessToken();
      // Fetch dynamic fee from system settings (mimicked endpoint)
      final feeResp = await Dio().get(
        '${ApiConstants.baseUrl}system/settings/fee/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final response = await Dio().get(
        '${ApiConstants.baseUrl}providers/nearby/',
        queryParameters: {
          'available': 'true',
          if (position != null) 'lat': position.latitude,
          if (position != null) 'lng': position.longitude,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (mounted) {
        setState(() { 
          final results = response.data is List ? response.data : (response.data['results'] ?? []);
          _doctors = results.isEmpty ? _getDemoDoctors() : results;
          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _doctors = _getDemoDoctors(); // Fallback to demo data for simulation
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _getDemoDoctors() {
    return [
      {
        'id': 'd1',
        'provider_id': {'id': 'p1', 'first_name': 'Amadou', 'last_name': 'Bello'},
        'specialization': 'Cardiologist',
        'rating': 4.9,
        'lat': 4.0511, 'lng': 9.7679,
        'status': 'Online',
        'is_available': true,
      },
      {
        'id': 'd2',
        'provider_id': {'id': 'p2', 'first_name': 'Claire', 'last_name': 'Nembot'},
        'specialization': 'Pediatrician',
        'rating': 4.7,
        'lat': 4.0611, 'lng': 9.7779,
        'status': 'Available',
        'is_available': true,
      },
      {
        'id': 'd3',
        'provider_id': {'id': 'p3', 'first_name': 'Abel', 'last_name': 'Tako'},
        'specialization': 'General Surgeon',
        'rating': 4.8,
        'lat': 4.0411, 'lng': 9.7579,
        'status': 'Busy',
        'is_available': false,
      },
    ];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            expandedHeight: 130,
            backgroundColor: AppColors.darkBlue900,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Find a Doctor', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white, fontSize: 22)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Browse verified healthcare providers', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(child: Center(child: Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400))))
          else if (_doctors.isEmpty)
            SliverFillRemaining(child: Center(child: Text('No doctors available right now', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400))))
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DoctorCard(doctor: _doctors[i]),
                  childCount: _doctors.length,
                ),
              ),
            )
        ],
      ),
    );
  }
}

class _DoctorSlideCard extends StatelessWidget {
  final dynamic doctor;
  final VoidCallback onClose;

  const _DoctorSlideCard({required this.doctor, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final name = '${doctor['provider_id']?['first_name'] ?? 'Dr.'} ${doctor['provider_id']?['last_name'] ?? ''}';
    final spec = doctor['specialization'] ?? 'General Practitioner';
    final rating = (doctor['rating'] ?? 0.0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.darkBlue700, AppColors.sky500]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_3_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.headlineSmall),
                    Row(
                      children: [
                        Text(spec, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky600)),
                        const SizedBox(width: 8),
                        _StatusBadge(status: doctor['status'] ?? 'Available'),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                        const SizedBox(width: 4),
                        Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: AppColors.grey400)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/patient/doctor-profile/${doctor['id'] ?? doctor['provider_id']?['id']}'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.sky500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/patient/book-appointment', extra: doctor),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sky600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Book Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final dynamic doctor;
  const _DoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final name = '${doctor['provider_id']?['first_name'] ?? 'Dr.'} ${doctor['provider_id']?['last_name'] ?? ''}';
    final spec = doctor['specialization'] ?? 'General Practitioner';
    final rating = (doctor['rating'] ?? 0.0).toStringAsFixed(1);
    final isAvailable = doctor['is_available'] == true;

    return GestureDetector(
      onTap: () => context.push('/patient/doctor-profile/${doctor['id'] ?? doctor['provider_id']?['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey200),
          boxShadow: [BoxShadow(color: AppColors.darkBlue900.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.darkBlue700.withOpacity(0.1), AppColors.sky500.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.person_outline_rounded, color: AppColors.sky600, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16)),
                      const SizedBox(width: 6),
                      _StatusDot(status: doctor['status'] ?? 'Available'),
                    ],
                  ),
                  Text(spec, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                      const SizedBox(width: 4),
                      Text(rating, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on_rounded, size: 14, color: AppColors.grey400),
                      const SizedBox(width: 4),
                      Text('Douala, CM', style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.grey200, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (status == 'Online') color = Colors.green;
    if (status == 'Available') color = Colors.yellow.shade700;
    if (status == 'Busy') color = Colors.orange;

    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (status == 'Online') color = Colors.green;
    if (status == 'Available') color = Colors.yellow.shade700;
    if (status == 'Busy') color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
