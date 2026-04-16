import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class NearbyClinicsScreen extends StatefulWidget {
  const NearbyClinicsScreen({super.key});

  @override
  State<NearbyClinicsScreen> createState() => _NearbyClinicsScreenState();
}

class _NearbyClinicsScreenState extends State<NearbyClinicsScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  final Set<Marker> _markers = {};
  BitmapDescriptor? _customMarkerIcon;
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _isSearching = false;
  bool _showListView = true;

  final List<Map<String, dynamic>> _clinics = [];
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredClinics {
    if (_searchQuery.trim().isEmpty) return _clinics;
    final q = _searchQuery.trim().toLowerCase();
    return _clinics.where((c) {
      final name = c['name']?.toString().toLowerCase() ?? '';
      final addr = c['address']?.toString().toLowerCase() ?? '';
      return name.contains(q) || addr.contains(q);
    }).toList();
  }
  Map<String, dynamic>? _selectedClinic;
  
  final _dio = Dio();
  final String _apiKey = dotenv.get('GOOGLE_MAPS_API_KEY');

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _determinePosition();
  }

  Future<void> _loadCustomMarker() async {
    _customMarkerIcon = await _createCustomMarkerIcon();
    _rebuildMarkers(); // Initial marker build if data is already there
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;
    
    // Draw outer glow/shadow
    final Paint shadowPaint = Paint()..color = AppColors.sky500.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.5, shadowPaint);

    // Draw main circle
    final Paint circlePaint = Paint()..color = AppColors.sky600;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 4, circlePaint);

    // Draw a subtle cross
    final Paint crossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const double crossSize = 12.0;
    canvas.drawLine(const Offset(size / 2 - crossSize, size / 2), const Offset(size / 2 + crossSize, size / 2), crossPaint);
    canvas.drawLine(const Offset(size / 2, size / 2 - crossSize), const Offset(size / 2, size / 2 + crossSize), crossPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() => _isLoading = true);

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
        _searchNearbyClinics(position);
        print('Location fetched successfully: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('Error fetching location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e. Using default view.')),
        );
        setState(() {
          _isLoading = false;
          // Use default position if location fails
          _currentPosition = Position(
            latitude: 4.0511, longitude: 9.7679,
            timestamp: DateTime.now(), accuracy: 0, altitude: 0,
            heading: 0, speed: 0, speedAccuracy: 0,
            altitudeAccuracy: 0, headingAccuracy: 0,
          );
        });
      }
    }
  }

  Future<void> _searchNearbyClinics(Position position) async {
    setState(() => _isSearching = true);
    
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${position.latitude},${position.longitude}'
          '&radius=5000'
          '&type=hospital'
          '&key=$_apiKey';

      final response = await _dio.get(url);
      
      if (response.data['status'] == 'OK') {
        final List results = response.data['results'];
        setState(() {
          _clinics.clear();
          for (var result in results) {
            _clinics.add({
              'id': result['place_id'],
              'name': result['name'],
              'lat': result['geometry']['location']['lat'],
              'lng': result['geometry']['location']['lng'],
              'address': result['vicinity'],
              'rating': result['rating']?.toString() ?? '0',
              'total_ratings': result['user_ratings_total']?.toString() ?? '0',
              'open_now': result['opening_hours']?['open_now'] ?? false,
            });
          }
          _rebuildMarkers();
        });
      }
    } catch (e) {
      print('Error searching clinics: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _rebuildMarkers() {
    if (_customMarkerIcon == null) return;

    setState(() {
      _markers.clear();
      for (var clinic in _clinics) {
        final isSelected = _selectedClinic != null && _selectedClinic!['id'] == clinic['id'];
        
        _markers.add(
          Marker(
            markerId: MarkerId(clinic['id']),
            position: LatLng(clinic['lat'], clinic['lng']),
            infoWindow: InfoWindow(title: clinic['name']),
            icon: _customMarkerIcon!,
            alpha: (_selectedClinic == null || isSelected) ? 1.0 : 0.2, // Subtle fading for others
            onTap: () {
              setState(() {
                _selectedClinic = clinic;
                _polylines.clear(); // Clear old polylines when selecting new marker
                _rebuildMarkers(); // Refresh opacities
              });
              _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(clinic['lat'], clinic['lng'])));
            },
          ),
        );
      }
    });
  }

  Future<void> _getDirections(double destLat, double destLng) async {
    if (_currentPosition == null) return;

    try {
      // Modern Google Routes API endpoint
      const url = 'https://routes.googleapis.com/directions/v2:computeRoutes';
      
      final body = {
        "origin": {
          "location": {
            "latLng": {
              "latitude": _currentPosition!.latitude,
              "longitude": _currentPosition!.longitude
            }
          }
        },
        "destination": {
          "location": {
            "latLng": {
              "latitude": destLat,
              "longitude": destLng
            }
          }
        },
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE",
        "computeAlternativeRoutes": false,
        "languageCode": "en-US",
        "units": "METRIC"
      };

      final response = await _dio.post(
        url,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'
          },
        ),
      );

      print('Routes API Response: ${response.data}');
      
      if (response.data['routes'] != null && (response.data['routes'] as List).isNotEmpty) {
        final encodedPolyline = response.data['routes'][0]['polyline']['encodedPolyline'];
        final polylinePoints = PolylinePoints.decodePolyline(encodedPolyline);
        
        final List<LatLng> polylineCoordinates = polylinePoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: AppColors.sky500,
              width: 5,
              points: polylineCoordinates,
            ),
          );
        });

        // Zoom to fit route
        _fitRoute(polylineCoordinates);
      } else {
        print('Routes API: No routes found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No route found to this clinic.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Error fetching routes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch route. Please ensure Routes API is enabled.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _fitRoute(List<LatLng> points) {
    if (_mapController == null) return;
    
    double minLat = points.first.latitude;
    double maxLat = minLat;
    double minLng = points.first.longitude;
    double maxLng = minLng;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // Padding
      ),
    );
  }

  String _calculateDistance(double clinicLat, double clinicLng) {
    if (_currentPosition == null) return '';
    final distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      clinicLat,
      clinicLng,
    );
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceInMeters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _showListView
                  ? _buildClinicListView()
                  : GoogleMap(
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_currentPosition?.latitude ?? 4.0511, _currentPosition?.longitude ?? 9.7679),
                        zoom: 14.5,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapType: MapType.normal,
                    ),

          // Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.darkBlue900.withOpacity(0.8),
                    AppColors.darkBlue900.withOpacity(0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      elevation: 4,
                      color: Colors.white,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(15),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        cursorColor: AppColors.sky500,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkBlue900, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search clinics nearby...',
                          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildIconButton(
                    _showListView ? Icons.map_rounded : Icons.list_rounded,
                    () => setState(() => _showListView = !_showListView),
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(Icons.tune_rounded, () {}),
                ],
              ),
            ),
          ),

          // Bottom clinic card
          if (_selectedClinic != null && !_showListView)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Material(
                elevation: 16,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(22),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => context.push('/patient/clinic-profile/${_selectedClinic!['id']}'),
                            icon: Icon(Icons.info_outline_rounded, size: 20, color: AppColors.splashSlate900),
                            label: Text(
                              'Details',
                              style: TextStyle(
                                color: AppColors.splashSlate900,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => setState(() {
                              _selectedClinic = null;
                              _polylines.clear();
                              _rebuildMarkers();
                            }),
                            icon: const Icon(Icons.close_rounded, color: AppColors.grey400),
                            style: IconButton.styleFrom(backgroundColor: AppColors.grey50),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: (_selectedClinic!['open_now'] ?? false)
                                        ? AppColors.accentGreen.withValues(alpha: 0.12)
                                        : AppColors.grey100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (_selectedClinic!['open_now'] ?? false) ? 'Open now' : 'Closed',
                                    style: AppTextStyles.caption.copyWith(
                                      color: (_selectedClinic!['open_now'] ?? false)
                                          ? AppColors.accentGreen
                                          : AppColors.grey500,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '${_selectedClinic!['rating']} (${_selectedClinic!['total_ratings']})',
                                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedClinic!['name'],
                              style: AppTextStyles.headlineMedium.copyWith(
                                fontSize: 18,
                                color: AppColors.splashSlate900,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_rounded, color: AppColors.sky500, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${_selectedClinic!['address']}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.grey500,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _getDirections(_selectedClinic!['lat'], _selectedClinic!['lng']),
                                    icon: const Icon(Icons.directions_rounded, size: 20),
                                    label: const Text('Directions'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.splashSlate900,
                                      side: BorderSide(color: AppColors.grey200),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () =>
                                        context.push('/patient/book-appointment', extra: _selectedClinic),
                                    icon: const Icon(Icons.calendar_today_rounded, size: 20),
                                    label: const Text('Book'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.splashSlate900,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Current Location Button
          if (!_showListView)
          Positioned(
            right: 24,
            bottom: _selectedClinic != null ? 300 : 120,
            child: FloatingActionButton(
              onPressed: _determinePosition,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: AppColors.darkBlue900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicListView() {
    final clinics = _filteredClinics;
    if (clinics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 160),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_hospital_outlined, size: 64, color: AppColors.grey200),
              const SizedBox(height: 16),
              Text('No clinics found nearby', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      top: 130,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: clinics.length,
        itemBuilder: (context, index) {
          final clinic = clinics[index];
          final isOpen = clinic['open_now'] ?? false;
          final distance = _calculateDistance(clinic['lat'], clinic['lng']);

          return GestureDetector(
            onTap: () => context.push('/patient/clinic-profile/${clinic['id']}'),
            child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.grey200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          clinic['name'] ?? '',
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOpen
                              ? AppColors.accentGreen.withValues(alpha: 0.12)
                              : AppColors.grey100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOpen ? 'Open' : 'Closed',
                          style: AppTextStyles.caption.copyWith(
                            color: isOpen ? AppColors.accentGreen : AppColors.grey500,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.sky500, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          clinic['address'] ?? '',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${clinic['rating']} (${clinic['total_ratings']})',
                        style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (distance.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.directions_walk_rounded, color: AppColors.grey400, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          distance,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.grey500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedClinic = clinic;
                              _showListView = false;
                            });
                            _getDirections(clinic['lat'], clinic['lng']);
                          },
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text('Directions'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.splashSlate900,
                            side: BorderSide(color: AppColors.grey200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => context.push('/patient/book-appointment', extra: clinic),
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: const Text('Book'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.splashSlate900,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: AppColors.darkBlue900),
      ),
    );
  }

}
