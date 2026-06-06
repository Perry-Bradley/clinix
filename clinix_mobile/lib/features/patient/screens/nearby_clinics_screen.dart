import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  BitmapDescriptor? _hospitalMarker;
  BitmapDescriptor? _pharmacyMarker;
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _isSearching = false;
  bool _showListView = true;

  final List<Map<String, dynamic>> _clinics = [];
  String _searchQuery = '';
  String _placeFilter = 'all'; // 'all', 'hospital', 'pharmacy'

  List<Map<String, dynamic>> get _filteredClinics {
    var list = _clinics;
    if (_placeFilter != 'all') {
      list = list.where((c) => c['type'] == _placeFilter).toList();
    }
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((c) {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen is resumed
    if (mounted && _currentPosition != null) {
      _searchNearbyClinics(_currentPosition!, silent: true);
    }
  }

  Future<void> _loadCustomMarker() async {
    _hospitalMarker = await _createCustomMarkerIcon(isPharmacy: false);
    _pharmacyMarker = await _createCustomMarkerIcon(isPharmacy: true);
    _rebuildMarkers(); // Initial marker build if data is already there
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon({required bool isPharmacy}) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;

    // Hospital: solid blue circle, white cross.
    // Pharmacy: white circle with thin blue ring, blue cross — visual inverse.
    final Color glowColor = AppColors.sky500.withOpacity(0.3);
    final Color bodyColor = isPharmacy ? Colors.white : AppColors.sky600;
    final Color crossColor = isPharmacy ? AppColors.sky600 : Colors.white;

    // Outer glow/shadow — same for both so they share the same "weight"
    final Paint shadowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.5, shadowPaint);

    // Main circle
    final Paint circlePaint = Paint()..color = bodyColor;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 4, circlePaint);

    // Pharmacy gets a thin blue border so the white body reads on the map
    if (isPharmacy) {
      final Paint borderPaint = Paint()
        ..color = AppColors.sky600
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(const Offset(size / 2, size / 2), size / 4, borderPaint);
    }

    // Cross
    final Paint crossPaint = Paint()
      ..color = crossColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const double crossSize = 12.0;
    canvas.drawLine(const Offset(size / 2 - crossSize, size / 2), const Offset(size / 2 + crossSize, size / 2), crossPaint);
    canvas.drawLine(const Offset(size / 2, size / 2 - crossSize), const Offset(size / 2, size / 2 + crossSize), crossPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  static Position _defaultPosition() => Position(
        latitude: 4.0511, longitude: 9.7679, // Douala
        timestamp: DateTime.now(),
        accuracy: 0, altitude: 0,
        heading: 0, speed: 0, speedAccuracy: 0,
        altitudeAccuracy: 0, headingAccuracy: 0,
      );

  Future<void> _determinePosition() async {
    setState(() => _isLoading = true);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final hasPermission = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    Position? position;

    if (serviceEnabled && hasPermission) {
      // Fast path — use cached last-known fix if available
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {/* ignore */}

      // Slow path — try a fresh fix; medium accuracy is faster
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 20),
        );
      } catch (e) {
        print('getCurrentPosition timed out, using ${position == null ? 'default' : 'last-known'} position: $e');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!serviceEnabled
              ? 'Location services are off — showing Douala area.'
              : 'Location permission denied — showing Douala area.')),
        );
      }
    }

    final resolved = position ?? _defaultPosition();
    if (!mounted) return;
    setState(() {
      _currentPosition = resolved;
      _isLoading = false;
    });

    // Show cached facilities immediately (if any), then refresh in background.
    final hadCache = await _loadFacilitiesFromCache(resolved);
    if (!hadCache) {
      // No cache → fetch live
      _searchNearbyClinics(resolved);
    } else {
      // Refresh silently in the background after showing cached UI
      _searchNearbyClinics(resolved, silent: true);
    }
  }

  static const _cacheTtl = Duration(days: 7);

  // Round coords to ~110m so a small phone wobble still hits the same cache.
  // The `v2` suffix invalidates earlier caches that included non-hospital/pharmacy places.
  String _cacheKey(Position p) =>
      'facilities_v2_${p.latitude.toStringAsFixed(3)}_${p.longitude.toStringAsFixed(3)}.json';

  Future<File> _cacheFile(Position p) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/${_cacheKey(p)}');
  }

  Future<bool> _loadFacilitiesFromCache(Position p) async {
    try {
      final f = await _cacheFile(p);
      if (!await f.exists()) return false;
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final ts = DateTime.tryParse(raw['ts']?.toString() ?? '');
      if (ts == null || DateTime.now().difference(ts) > _cacheTtl) return false;
      final list = (raw['clinics'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (list.isEmpty) return false;
      _clinics
        ..clear()
        ..addAll(list);
      _rebuildMarkers();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeFacilitiesCache(Position p) async {
    try {
      final f = await _cacheFile(p);
      await f.writeAsString(jsonEncode({
        'ts': DateTime.now().toIso8601String(),
        'clinics': _clinics,
      }));
    } catch (_) {/* non-fatal */}
  }

  Future<void> _searchNearbyClinics(Position position, {bool silent = false}) async {
    if (!silent) setState(() => _isSearching = true);

    // Hospitals and pharmacies only — nothing else.
    const queries = <Map<String, String>>[
      {'type': 'hospital', 'bucket': 'hospital'},
      {'type': 'pharmacy', 'bucket': 'pharmacy'},
    ];

    try {
      final seen = <String>{}; // dedupe by place_id
      final fresh = <Map<String, dynamic>>[];

      // Fetch Google Places data
      final futures = queries.map((q) async {
        final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${position.latitude},${position.longitude}'
            '&radius=15000' // 15 km — was 5 km, too tight for most cities
            '&type=${q['type']}'
            '&key=$_apiKey';
        final response = await _dio.get(url);
        if (response.data['status'] != 'OK') return;
        final List results = response.data['results'];
        for (var r in results) {
          final id = r['place_id']?.toString();
          if (id == null || seen.contains(id)) continue;
          seen.add(id);
          fresh.add({
            'id': id,
            'name': r['name'],
            'lat': r['geometry']['location']['lat'],
            'lng': r['geometry']['location']['lng'],
            'address': r['vicinity'],
            'rating': r['rating']?.toString() ?? '0',
            'total_ratings': r['user_ratings_total']?.toString() ?? '0',
            'open_now': r['opening_hours']?['open_now'] ?? false,
            'type': q['bucket'],
            'photo_ref': _firstPhotoRef(r['photos']),
            'phone_number': null, // Will be filled from backend
          });
        }
      });
      await Future.wait(futures);

      // Fetch backend facilities with phone numbers (hybrid approach)
      try {
        final backendFacilities = await _fetchBackendFacilities();
        // Match Google Places with backend facilities by name/address
        for (var clinic in fresh) {
          final googleName = clinic['name']?.toString().toLowerCase() ?? '';
          final googleAddress = clinic['address']?.toString().toLowerCase() ?? '';
          
          // Try to find matching backend facility
          for (var backendFac in backendFacilities) {
            final backendName = backendFac['facility_name']?.toString().toLowerCase() ?? '';
            final backendAddress = backendFac['address']?.toString().toLowerCase() ?? '';
            
            // Match if names are similar or addresses match
            if ((googleName.contains(backendName) || backendName.contains(googleName)) ||
                (googleAddress.contains(backendAddress) || backendAddress.contains(googleAddress))) {
              clinic['phone_number'] = backendFac['phone_number'];
              break;
            }
          }
        }
      } catch (e) {
        print('Error fetching backend facilities: $e');
        // Continue without phone numbers if backend fetch fails
      }

      if (fresh.isEmpty) {
        // Don't wipe a good cache when the network call returns nothing.
        if (!silent && mounted) setState(() => _isSearching = false);
        return;
      }

      // Sort by distance from user — closest first
      fresh.sort((a, b) {
        final da = _distanceMeters(position.latitude, position.longitude,
            (a['lat'] as num).toDouble(), (a['lng'] as num).toDouble());
        final db = _distanceMeters(position.latitude, position.longitude,
            (b['lat'] as num).toDouble(), (b['lng'] as num).toDouble());
        return da.compareTo(db);
      });

      _clinics
        ..clear()
        ..addAll(fresh);
      setState(() => _rebuildMarkers());
      _writeFacilitiesCache(position);
    } catch (e) {
      print('Error searching places: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBackendFacilities() async {
    try {
      final response = await _dio.get(
        'https://clinix-production-81cf.up.railway.app/api/v1/locations/facilities/',
      );
      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      print('Error fetching backend facilities: $e');
      return [];
    }
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  String? _firstPhotoRef(dynamic photos) {
    if (photos is List && photos.isNotEmpty) {
      return photos.first['photo_reference']?.toString();
    }
    return null;
  }

  void _showPlaceFilterSheet() {
    const options = [
      {'key': 'all', 'label': 'All places'},
      {'key': 'hospital', 'label': 'Hospitals only'},
      {'key': 'pharmacy', 'label': 'Pharmacies only'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Filter Places',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.splashSlate900,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final selected = _placeFilter == opt['key'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _placeFilter = opt['key']!;
                      _rebuildMarkers();
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.darkBlue800 : AppColors.grey50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.darkBlue800 : AppColors.grey200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: selected ? Colors.white : AppColors.grey400,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          opt['label']!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: selected ? Colors.white : AppColors.splashSlate900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _rebuildMarkers() {
    if (_hospitalMarker == null || _pharmacyMarker == null) return;

    setState(() {
      _markers.clear();
      final visiblePlaces = _placeFilter == 'all' ? _clinics : _clinics.where((c) => c['type'] == _placeFilter).toList();
      for (var clinic in visiblePlaces) {
        final isSelected = _selectedClinic != null && _selectedClinic!['id'] == clinic['id'];
        final isPharmacy = clinic['type'] == 'pharmacy';

        _markers.add(
          Marker(
            markerId: MarkerId(clinic['id']),
            position: LatLng(clinic['lat'], clinic['lng']),
            infoWindow: InfoWindow(title: '${isPharmacy ? "💊 " : "🏥 "}${clinic['name']}'),
            icon: isPharmacy ? _pharmacyMarker! : _hospitalMarker!,
            alpha: (_selectedClinic == null || isSelected) ? 1.0 : 0.3,
            onTap: () {
              setState(() {
                _selectedClinic = clinic;
                _polylines.clear();
                _rebuildMarkers();
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
                      myLocationEnabled: false,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
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
                              hintText: 'Search clinics & pharmacies...',
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
                      _buildIconButton(Icons.tune_rounded, () => _showPlaceFilterSheet()),
                    ],
                  ),
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
                                    onPressed: () => context.push(
                                      '/patient/clinic-profile/${_selectedClinic!['id']}',
                                    ),
                                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                                    label: const Text('View Details'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.darkBlue500,
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _determinePosition(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sky600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      top: 130,
      child: RefreshIndicator(
        onRefresh: () => _determinePosition(),
        color: AppColors.sky600,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: clinics.length,
          itemBuilder: (context, index) {
            final clinic = clinics[index];
            final isOpen = clinic['open_now'] ?? false;
            final distance = _calculateDistance(clinic['lat'], clinic['lng']);
            final phoneNumber = clinic['phone_number']?.toString();

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
                  if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, color: AppColors.sky500, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            phoneNumber,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.sky600,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                          onPressed: () => context.push(
                            '/patient/clinic-profile/${clinic['id']}',
                          ),
                          icon: const Icon(Icons.info_outline_rounded, size: 18),
                          label: const Text('View Details'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.darkBlue500,
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

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch call to $phoneNumber')),
        );
      }
    }
  }

}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkBlue500 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.darkBlue500 : AppColors.grey200),
          boxShadow: selected ? [BoxShadow(color: AppColors.darkBlue500.withOpacity(0.2), blurRadius: 6)] : [],
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.grey500)),
      ),
    );
  }
}
