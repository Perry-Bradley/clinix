import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_colors.dart';

/// Full-screen map: pan, tap to place pin, or use device GPS. Returns lat/lng (+ optional formatted address).
class MapLocationPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  final String title;

  const MapLocationPickerScreen({
    super.key,
    this.initialPosition,
    this.title = 'Set location on map',
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  late LatLng _center;
  Set<Marker> _markers = {};
  GoogleMapController? _controller;
  bool _busy = false;
  String? _status;

  static const LatLng _defaultYaounde = LatLng(3.8480, 11.5021);

  @override
  void initState() {
    super.initState();
    _center = widget.initialPosition ?? _defaultYaounde;
    _setPin(_center, animateCamera: false);
  }

  void _setPin(LatLng p, {bool animateCamera = true}) {
    setState(() {
      _center = p;
      _markers = {
        Marker(
          markerId: const MarkerId('pick'),
          position: p,
          draggable: true,
          onDragEnd: (np) => _setPin(np, animateCamera: false),
        ),
      };
    });
    if (animateCamera) {
      _controller?.animateCamera(CameraUpdate.newLatLng(p));
    }
  }

  Future<void> _useGps() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _status = 'Turn on location services.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _status = 'Location permission is required.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final ll = LatLng(pos.latitude, pos.longitude);
      _setPin(ll);
    } catch (e) {
      if (mounted) setState(() => _status = 'Could not read GPS: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _reverseGeocode(LatLng p) async {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) return null;
    try {
      final dio = Dio();
      final r = await dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${p.latitude},${p.longitude}',
          'key': key,
        },
      );
      final results = r.data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      return results.first['formatted_address']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final addr = await _reverseGeocode(_center);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop<Map<String, dynamic>>({
      'latitude': _center.latitude,
      'longitude': _center.longitude,
      'formatted_address': addr,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashSlate900,
      appBar: AppBar(
        backgroundColor: AppColors.splashSlate900,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 15),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) => _controller = c,
            onTap: (p) => _setPin(p),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tap the map or drag the pin to your exact practice or residence.',
                      style: TextStyle(color: AppColors.grey700, fontSize: 13, height: 1.35),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 8),
                      Text(_status!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _useGps,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 18),
                            label: const Text('Use GPS'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : _confirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.splashSlate900,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Use this location'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
