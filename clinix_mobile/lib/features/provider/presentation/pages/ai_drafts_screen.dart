import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';

/// Lists the doctor's pending AI report drafts (AI-generated, not yet
/// published) so they can open and review one at any time — not only from the
/// push notification. Tapping a draft opens the same review/edit form.
class AiDraftsScreen extends StatefulWidget {
  const AiDraftsScreen({super.key});

  @override
  State<AiDraftsScreen> createState() => _AiDraftsScreenState();
}

class _AiDraftsScreenState extends State<AiDraftsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _drafts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}records/?drafts=1',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      final list = data is List
          ? data
          : (data is Map && data['results'] is List ? data['results'] as List : const []);
      _drafts = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      _error = 'Could not load AI drafts.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'AI report drafts',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkBlue900,
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _Message(text: _error!, onRetry: _load)
                : _drafts.isEmpty
                    ? const _Message(
                        text:
                            'No AI drafts yet.\nThey appear here after a recorded consultation.')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _drafts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final d = _drafts[i];
                          final id = (d['record_id'] ?? '').toString();
                          final title = (d['title'] ?? '').toString();
                          final patient = (d['patient_name'] ?? '').toString();
                          final when = _formatDate(d['created_at']?.toString());
                          return _DraftCard(
                            title: title.isEmpty ? 'Untitled draft' : title,
                            patient: patient,
                            when: when,
                            onTap: () {
                              if (id.isEmpty) return;
                              context.push(
                                  '/provider/medical-record/new?aiDraftRecordId=$id');
                            },
                          );
                        },
                      ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final String title;
  final String patient;
  final String when;
  final VoidCallback onTap;
  const _DraftCard({
    required this.title,
    required this.patient,
    required this.when,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.darkBlue500.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.darkBlue500, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.darkBlue900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [if (patient.isNotEmpty) patient, if (when.isNotEmpty) when]
                          .join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.grey500),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.auto_awesome_outlined,
            size: 56, color: AppColors.grey500.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.grey500,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        ],
      ],
    );
  }
}
