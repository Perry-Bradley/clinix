import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:clinix_mobile/core/constants/api_constants.dart';

class NearbyClinicsMapScreen extends StatefulWidget {
  const NearbyClinicsMapScreen({super.key});

  @override
  State<NearbyClinicsMapScreen> createState() => _NearbyClinicsMapScreenState();
}

class _NearbyClinicsMapScreenState extends State<NearbyClinicsMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  Set<Marker> _markers = {};
  Position? _currentPosition;
  bool _isLoading = true;

  static const CameraPosition _defaultCam = CameraPosition(
    target: LatLng(3.8480, 11.5021),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _isLoading = false;
    });

    await _animateToUser();
    await _fetchNearbyClinics();
  }

  Future<void> _animateToUser() async {
    if (_currentPosition == null) return;
    final c = await _mapController.future;
    await c.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 14.0,
      ),
    ));
  }

  Future<void> _fetchNearbyClinics() async {
    try {
      final c = await _mapController.future;
      final bounds = await c.getVisibleRegion();
      final boundsStr =
          '${bounds.southwest.latitude},${bounds.southwest.longitude},${bounds.northeast.latitude},${bounds.northeast.longitude}';

      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await dio.get('locations/providers/map/', queryParameters: {'bounds': boundsStr});

      final raw = response.data;
      final List<dynamic> data = raw is List<dynamic> ? raw : <dynamic>[];

      final newMarkers = <Marker>{};
      for (final item in data) {
        if (item is! Map) continue;
        final provider = Map<String, dynamic>.from(item);
        final locations = provider['locations'] as List? ?? [];
        for (final loc in locations) {
          if (loc is! Map) continue;
          final m = Map<String, dynamic>.from(loc);
          if (m['latitude'] == null || m['longitude'] == null) continue;
          final lat = double.parse(m['latitude'].toString());
          final lng = double.parse(m['longitude'].toString());
          final id = m['location_id']?.toString() ?? '${lat}_$lng';

          newMarkers.add(Marker(
            markerId: MarkerId('loc_$id'),
            position: LatLng(lat, lng),
            onTap: () => showClinicDetails(provider, m),
            infoWindow: InfoWindow(
              title: m['facility_name']?.toString() ?? provider['full_name']?.toString() ?? 'Clinic',
              snippet: provider['specialty']?.toString() ?? 'Healthcare',
            ),
          ));
        }
      }

      if (mounted) setState(() => _markers = newMarkers);
    } catch (e) {
      debugPrint('Error fetching map points: $e');
    }
  }

  void showClinicDetails(Map<String, dynamic> provider, Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.withValues(alpha: 0.2),
                  backgroundImage: provider['user_photo'] != null ? NetworkImage(provider['user_photo'].toString()) : null,
                  child: provider['user_photo'] == null ? const Icon(Icons.apartment, color: Colors.blue) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location['facility_name']?.toString() ?? provider['full_name']?.toString() ?? 'Clinic',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        provider['specialty']?.toString() ?? 'General Practice',
                        style: TextStyle(color: Colors.blue.shade300, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 4),
                      Text('${provider['rating'] ?? '4.8'}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            const Text('ADDRESS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            Text(
              '${location['address'] ?? 'No address provided'}, ${location['city'] ?? ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  final pid = provider['provider_id'];
                  final id = pid is Map ? pid['user_id']?.toString() ?? pid.toString() : pid.toString();
                  context.push('/patient/doctor-profile/$id');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('VIEW DETAILS & BOOK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby clinics'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _defaultCam,
            markers: _markers,
            myLocationEnabled: true,
            onMapCreated: (c) {
              if (!_mapController.isCompleted) _mapController.complete(c);
            },
            onCameraIdle: () => _fetchNearbyClinics(),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
