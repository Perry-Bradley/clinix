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
  String _searchQuery = '';
  String _selectedSpecialty = 'All';

  dynamic _selectedDoctor;
  Position? _currentPosition;

  List<dynamic> get _filteredDoctors {
    return _doctors.where((doctor) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (doctor['full_name'] ?? '').toString().toLowerCase();
        final specialty = (doctor['specialty'] ?? '').toString().toLowerCase();
        final otherSpecialty = (doctor['other_specialty'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !specialty.contains(query) && !otherSpecialty.contains(query)) {
          return false;
        }
      }

      // Filter by selected specialty
      if (_selectedSpecialty != 'All') {
        final specialty = (doctor['specialty'] ?? '').toString().toLowerCase();
        if (_selectedSpecialty == 'Specialist') {
          if (specialty != 'other') return false;
        } else {
          if (specialty != _selectedSpecialty.toLowerCase()) return false;
        }
      }

      return true;
    }).toList();
  }

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
      final response = await Dio().get(
        '${ApiConstants.baseUrl}providers/nearby/',
        queryParameters: {
          // 'available': 'true',
          if (position != null) 'lat': position.latitude,
          if (position != null) 'lng': position.longitude,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (mounted) {
        setState(() { 
          List<dynamic> results = [];
          
          if (response.data is List) {
            results = response.data;
          } else if (response.data is Map) {
            results = response.data['results'] ?? [];
          } else {
            // Handle cases where response.data is a String (e.g. HTML 500 error)
            _error = 'Backend returned an unexpected response format.';
          }
          
          _doctors = results;
          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load doctors. Please check your connection and backend setup.';
          _doctors = [];
          _isLoading = false;
        });
      }
    }
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
          // Search bar and specialty filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search by name or specialty...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.grey200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.grey200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.sky500, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'Generalist', 'Nurse', 'Midwife', 'Specialist'].map((specialty) {
                        final isSelected = _selectedSpecialty == specialty;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(specialty),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedSpecialty = specialty),
                            selectedColor: AppColors.sky500,
                            backgroundColor: AppColors.white,
                            labelStyle: AppTextStyles.caption.copyWith(
                              color: isSelected ? AppColors.white : AppColors.grey500,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isSelected ? AppColors.sky500 : AppColors.grey200),
                            ),
                            showCheckmark: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(child: Center(child: Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400))))
          else if (_filteredDoctors.isEmpty)
            SliverFillRemaining(child: Center(child: Text('No doctors match your search', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400))))
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _DoctorCard(doctor: _filteredDoctors[i]),
                  childCount: _filteredDoctors.length,
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
    final name = doctor['full_name']?.toString() ?? 'Doctor';
    final spec = doctor['other_specialty']?.toString().isNotEmpty == true
        ? doctor['other_specialty'].toString()
        : (doctor['specialty']?.toString() ?? 'General Practitioner');
    final rating = (double.tryParse(doctor['rating']?.toString() ?? '') ?? 0.0).toStringAsFixed(1);

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
                        _StatusBadge(status: (doctor['is_available'] == true) ? 'Available' : 'Offline'),
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
    final name = doctor['full_name']?.toString() ?? 'Doctor';
    final spec = (doctor['other_specialty']?.toString().isNotEmpty == true)
        ? doctor['other_specialty']
        : (doctor['specialty'] ?? 'General Practitioner');
    final ratingValue = double.tryParse(doctor['rating']?.toString() ?? '0.0') ?? 0.0;
    final rating = ratingValue.toStringAsFixed(1);
    final status = doctor['status']?.toString() ?? 'Offline';

    // Get real location from provider data
    final locations = (doctor['locations'] as List?) ?? [];
    String locationText = 'Location unavailable';
    if (locations.isNotEmpty) {
      final loc = locations.first;
      final city = loc['city']?.toString() ?? '';
      final region = loc['region']?.toString() ?? '';
      locationText = [city, region].where((s) => s.isNotEmpty).join(', ');
      if (locationText.isEmpty) locationText = loc['address']?.toString() ?? 'Location unavailable';
    }

    return GestureDetector(
      onTap: () => context.push('/patient/doctor-profile/${doctor['provider_id']}'),
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
                color: AppColors.sky100,
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
                      Flexible(child: Text(name, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      _StatusDot(status: status),
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
                      Flexible(child: Text(locationText, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/dchat/launch/${doctor['provider_id']}?name=${Uri.encodeComponent(name)}'),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sky500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
              ),
            ),
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
