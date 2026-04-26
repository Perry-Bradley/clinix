import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// WhatsApp-style call log. Each row is a Notification record persisted by
/// the backend's missed-call hook (and, in future, an answered-call hook).
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<Map<String, dynamic>> _calls = const [];
  bool _loading = true;
  String? _error;

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
        '${ApiConstants.baseUrl}${ApiConstants.consultations}calls/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      if (mounted) {
        setState(() {
          _calls = data is List
              ? data.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : const [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load call history.';
          _loading = false;
        });
      }
    }
  }

  String _whenLabel(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;
    final hhmm = DateFormat('HH:mm').format(dt);
    if (diff == 0) return 'Today, $hhmm';
    if (diff == 1) return 'Yesterday, $hhmm';
    if (diff < 7) return '${DateFormat('EEEE').format(dt)}, $hhmm';
    return DateFormat('d MMM, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.darkBlue900, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Calls',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.grey200),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.darkBlue500))
          : _error != null
              ? Center(child: Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)))
              : _calls.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_disabled_rounded, size: 48, color: AppColors.grey200),
                          const SizedBox(height: 12),
                          Text('No calls yet',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.darkBlue500,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _calls.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.grey100),
                        itemBuilder: (_, i) => _CallRow(
                          call: _calls[i],
                          whenLabel: _whenLabel(_calls[i]['sent_at']?.toString()),
                        ),
                      ),
                    ),
    );
  }
}

class _CallRow extends StatelessWidget {
  final Map<String, dynamic> call;
  final String whenLabel;
  const _CallRow({required this.call, required this.whenLabel});

  String _initials(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'^(Dr\.?|Doctor|Mr\.?|Mrs\.?|Ms\.?)\s+',
            caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final direction = call['direction']?.toString() ?? '';
    final isIncoming = direction == 'incoming';
    final title = call['title']?.toString() ?? 'Call';
    // For incoming the title is "Missed call from <name>" — strip the prefix
    // so the row shows the name only.
    String displayName = call['caller_name']?.toString() ?? '';
    if (displayName.isEmpty) {
      final m = RegExp(r'(?:from|with)\s+(.+)$', caseSensitive: false).firstMatch(title);
      if (m != null) {
        displayName = m.group(1) ?? title;
      } else {
        displayName = title;
      }
    }
    final appointmentId = call['appointment_id']?.toString();

    final iconColor = isIncoming ? AppColors.error : AppColors.grey500;
    final icon = isIncoming ? Icons.call_received_rounded : Icons.call_made_rounded;

    return InkWell(
      onTap: appointmentId != null && appointmentId.isNotEmpty
          ? () => context.push('/appointments/$appointmentId')
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.darkBlue500,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials(displayName),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.darkBlue900,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(icon, size: 13, color: iconColor),
                      const SizedBox(width: 4),
                      Text(
                        isIncoming ? 'Missed' : 'Outgoing · No answer',
                        style: AppTextStyles.caption.copyWith(
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        whenLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }
}
