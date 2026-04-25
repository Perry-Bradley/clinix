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
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DoctorsHeader(
              searchQuery: _searchQuery,
              selectedSpecialty: _selectedSpecialty,
              onSearchChanged: (v) => setState(() => _searchQuery = v),
              onSpecialtyChanged: (v) => setState(() => _selectedSpecialty = v),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
        ),
      );
    }
    if (_filteredDoctors.isEmpty) {
      return Center(
        child: Text('No doctors match your search', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: _filteredDoctors.length,
      itemBuilder: (ctx, i) => _DoctorCard(doctor: _filteredDoctors[i]),
    );
  }
}

class _DoctorsHeader extends StatelessWidget {
  final String searchQuery;
  final String selectedSpecialty;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSpecialtyChanged;

  const _DoctorsHeader({
    required this.searchQuery,
    required this.selectedSpecialty,
    required this.onSearchChanged,
    required this.onSpecialtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = selectedSpecialty != 'All';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.grey200, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top app-bar row: title + filter action
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Find a Doctor',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkBlue900,
                  ),
                ),
              ),
              _HeaderIconButton(
                icon: Icons.tune_rounded,
                showDot: hasActiveFilter,
                onTap: () => _showFilterSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.grey200),
            ),
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.darkBlue900),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search doctors, specialty...',
                hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.grey400),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    const specs = ['All', 'Generalist', 'Nurse', 'Midwife', 'Specialist'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Text(
                'Filter Doctors',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBlue900,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Specialty',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: specs.map((s) {
                  final sel = s == selectedSpecialty;
                  return GestureDetector(
                    onTap: () {
                      onSpecialtyChanged(s);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.darkBlue800 : AppColors.grey50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? AppColors.darkBlue800 : AppColors.grey200),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppColors.grey700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.darkBlue800,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (showDot)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
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
