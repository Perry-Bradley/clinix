import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A text field with Google Places autocomplete dropdown (Cameroon-biased).
class PlacesAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String address, double? lat, double? lng)? onSelected;

  const PlacesAutocompleteField({
    super.key,
    required this.controller,
    required this.hint,
    this.onSelected,
  });

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  Timer? _debounce;
  List<Map<String, dynamic>> _predictions = [];
  bool _loading = false;
  bool _suppressNext = false;

  String get _apiKey {
    try {
      return dotenv.get('GOOGLE_MAPS_API_KEY', fallback: '');
    } catch (_) {
      return '';
    }
  }

  Future<void> _fetchPredictions(String input) async {
    if (input.trim().length < 2 || _apiKey.isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&components=country:cm'
        '&key=$_apiKey',
      );
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final List preds = data['predictions'] ?? [];
        if (mounted) {
          setState(() {
            _predictions = preds.map((p) => Map<String, dynamic>.from(p as Map)).toList();
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPrediction(Map<String, dynamic> p) async {
    _suppressNext = true;
    widget.controller.text = p['description']?.toString() ?? '';
    widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: widget.controller.text.length));
    setState(() => _predictions = []);

    final placeId = p['place_id']?.toString();
    if (placeId == null || _apiKey.isEmpty) {
      widget.onSelected?.call(widget.controller.text, null, null);
      return;
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$_apiKey',
      );
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final loc = data['result']?['geometry']?['location'];
        if (loc != null) {
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          widget.onSelected?.call(widget.controller.text, lat, lng);
          return;
        }
      }
    } catch (_) {}
    widget.onSelected?.call(widget.controller.text, null, null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          onChanged: (v) {
            if (_suppressNext) { _suppressNext = false; return; }
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () => _fetchPredictions(v));
          },
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.splashSlate900),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400),
            prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.sky500, size: 20),
            suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky500))) : null,
            filled: true,
            fillColor: AppColors.grey50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.sky500, width: 1.2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        if (_predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Column(
              children: _predictions.take(5).map((p) {
                return InkWell(
                  onTap: () => _selectPrediction(p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 18, color: AppColors.grey500),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p['description']?.toString() ?? '', style: AppTextStyles.bodyMedium.copyWith(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
