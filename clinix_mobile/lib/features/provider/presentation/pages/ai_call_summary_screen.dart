import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';

/// Editable, sectioned AI call summary.
///
/// The AI drafts a summary of the whole call into sections; the doctor can edit
/// each section and Submit. It's saved on the server, so it's always reachable
/// again from the AI drafts screen. This is the doctor's note — not the manual
/// report template.
class AiCallSummaryScreen extends StatefulWidget {
  final String consultationId;
  final String? patientName;
  final List<dynamic>? initialSections; // [{key,label,text}] from finalize

  const AiCallSummaryScreen({
    super.key,
    required this.consultationId,
    this.patientName,
    this.initialSections,
  });

  @override
  State<AiCallSummaryScreen> createState() => _AiCallSummaryScreenState();
}

class _Section {
  final String key;
  final String label;
  final TextEditingController ctrl;
  _Section(this.key, this.label, String text) : ctrl = TextEditingController(text: text);
}

class _AiCallSummaryScreenState extends State<AiCallSummaryScreen> {
  bool _loading = false;
  bool _saving = false;
  String? _error;
  bool _submitted = false;
  final List<_Section> _sections = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSections;
    if (initial != null && initial.isNotEmpty) {
      _build(initial);
    } else {
      _fetch();
    }
  }

  void _build(List<dynamic> raw) {
    _sections
      ..clear()
      ..addAll(raw.whereType<Map>().map((m) => _Section(
            (m['key'] ?? '').toString(),
            (m['label'] ?? '').toString(),
            (m['text'] ?? '').toString(),
          )));
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}${widget.consultationId}/ai-summary/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data is Map ? res.data as Map : const {};
      _submitted = data['submitted'] == true;
      _build((data['sections'] as List?) ?? const []);
    } catch (_) {
      _error = 'Could not load the AI summary.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final token = await AuthService.getAccessToken();
      final sections = {for (final s in _sections) s.key: s.ctrl.text};
      await Dio().patch(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}${widget.consultationId}/ai-summary/',
        data: {'sections': sections, 'submitted': true},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save — please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final s in _sections) {
      s.ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('AI call summary',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkBlue900,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Inter', color: AppColors.grey500)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _fetch, child: const Text('Retry')),
                    ]),
                  ),
                )
              : Column(children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      children: [
                        _banner(),
                        const SizedBox(height: 14),
                        for (final s in _sections) _sectionCard(s),
                      ],
                    ),
                  ),
                  _bottomBar(),
                ]),
    );
  }

  Widget _banner() {
    final who = (widget.patientName ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkBlue500.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome_rounded, color: AppColors.darkBlue500, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              who.isEmpty ? 'AI summary — review & edit' : 'Summary · $who',
              style: const TextStyle(
                  fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.darkBlue900),
            ),
            const SizedBox(height: 2),
            Text(
              _submitted ? 'Submitted — you can still edit and re-submit.'
                         : 'Edit any section, then Submit to save.',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.grey500),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionCard(_Section s) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          s.label,
          style: const TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.darkBlue900),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: s.ctrl,
          minLines: 3,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, height: 1.45, color: Color(0xFF374151)),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF7F9FC),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit report',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}
