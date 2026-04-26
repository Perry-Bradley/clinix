import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/appointment_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../screens/video_consultation_screen.dart';

class AppointmentDetailPage extends StatefulWidget {
  final String appointmentId;
  const AppointmentDetailPage({super.key, required this.appointmentId});

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  Map<String, dynamic>? _appointment;
  Map<String, dynamic>? _consultation;
  bool _loading = true;
  bool _isProvider = false;
  bool _endingSession = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _resolveRole();
  }

  Future<void> _resolveRole() async {
    final type = await AuthService.getUserType();
    if (mounted) setState(() => _isProvider = type == 'provider');
  }

  String? _patientIdFromAppointment() {
    final a = _appointment;
    if (a == null) return null;
    final p = a['patient'];
    if (p is String) return p;
    if (p is Map) {
      final id = p['patient_id'] ?? p['id'] ?? p['user_id'];
      if (id != null) return id.toString();
    }
    return null;
  }

  String? _consultationId() {
    final a = _appointment;
    if (a == null) return null;
    final raw = a['consultation_id']?.toString();
    return (raw != null && raw.isNotEmpty) ? raw : null;
  }

  Future<void> _load() async {
    try {
      final a = await AppointmentService.getAppointment(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _appointment = a;
        _loading = false;
      });
      _loadConsultation();
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load appointment.'; _loading = false; });
    }
  }

  Future<void> _loadConsultation() async {
    final cid = _consultationId();
    if (cid == null) return;
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}$cid/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted && res.data is Map) {
        setState(() => _consultation = Map<String, dynamic>.from(res.data as Map));
      }
    } catch (_) {}
  }

  bool get _sessionEnded {
    final c = _consultation;
    if (c == null) return false;
    return c['ended_at'] != null && c['ended_at'].toString().isNotEmpty;
  }

  Future<void> _endSession() async {
    if (_endingSession) return;
    final cid = _consultationId();
    if (cid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active consultation to end.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'End consultation?',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'This officially closes the session and locks the report. '
          'Make sure you\u2019ve written the report, issued any prescriptions, '
          'and made referrals if needed.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not yet',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('End Session', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _endingSession = true);
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().patch(
        '${ApiConstants.baseUrl}${ApiConstants.consultations}$cid/end/',
        data: const {},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted && res.data is Map) {
        setState(() => _consultation = Map<String, dynamic>.from(res.data as Map));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended.'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?.toString() ?? 'Could not end session.')),
        );
      }
    } finally {
      if (mounted) setState(() => _endingSession = false);
    }
  }

  Future<void> _joinCall() async {
    if (_appointment == null) return;
    final a = _appointment!;
    final consultationId = a['consultation_id']?.toString() ?? widget.appointmentId;
    final providerName = _peerName();
    final audioOnly = (a['appointment_type']?.toString() ?? 'virtual') != 'virtual';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoConsultationScreen(
          consultationId: consultationId,
          doctorName: providerName,
          audioOnly: audioOnly,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: const Text('Are you sure you want to cancel this appointment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AppointmentService.cancelAppointment(widget.appointmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment cancelled'), backgroundColor: AppColors.accentGreen));
        // Signal the parent screen so it can refresh its appointment list.
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel'), backgroundColor: Colors.redAccent));
      }
    }
  }

  String? _providerId() {
    final p = (_appointment ?? {})['provider'];
    if (p is String) return p;
    if (p is Map) {
      final id = p['provider_id'] ?? p['id'] ?? p['user']?['user_id'];
      if (id != null) return id.toString();
    }
    return null;
  }

  String _initialsFromName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'^(Dr\.?|Doctor|Mr\.?|Mrs\.?|Ms\.?)\s+', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  void _openChat() {
    final pid = _providerId();
    final name = _peerName();
    if (pid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify the provider for chat.')),
      );
      return;
    }
    context.push('/dchat/launch/$pid?name=${Uri.encodeComponent(name)}');
  }

  String _peerName() {
    final a = _appointment ?? {};
    final p = a['provider'];
    if (p is Map) {
      return p['full_name']?.toString() ?? p['user']?['full_name']?.toString() ?? 'Provider';
    }
    return 'Provider';
  }

  String _specialty() {
    final p = (_appointment ?? {})['provider'];
    if (p is Map) {
      final other = p['other_specialty']?.toString();
      if (other != null && other.isNotEmpty) return other;
      return p['specialty']?.toString() ?? 'Healthcare Provider';
    }
    return 'Healthcare Provider';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed': return AppColors.darkBlue500;
      case 'completed': return AppColors.accentGreen;
      case 'cancelled': return AppColors.error;
      case 'no_show': return AppColors.grey500;
      default: return AppColors.accentOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.darkBlue500)),
      );
    }
    if (_error != null || _appointment == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 18), onPressed: () => context.pop()),
        ),
        body: Center(child: Text(_error ?? 'Appointment not found', style: AppTextStyles.bodyMedium)),
      );
    }

    final a = _appointment!;
    final status = a['status']?.toString() ?? 'pending';
    final type = a['appointment_type']?.toString() ?? 'virtual';
    final scheduledAtStr = a['scheduled_at']?.toString();
    final scheduledAt = scheduledAtStr != null ? DateTime.tryParse(scheduledAtStr)?.toLocal() : null;
    final duration = a['duration_minutes'] ?? 30;
    final endAt = scheduledAt?.add(Duration(minutes: duration is int ? duration : 30));
    final reason = (a['cancellation_reason'] ?? '').toString();
    final feeRaw = (a['provider'] is Map) ? a['provider']['consultation_fee'] : null;
    final fee = double.tryParse(feeRaw?.toString() ?? '') ?? 0;

    final canJoin = (status == 'confirmed' || status == 'pending') && type == 'virtual';
    final canCancel = status == 'pending' || status == 'confirmed';
    final canMessage = !_isProvider && status != 'cancelled';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Appointment',
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          // ── Hero: clean initials avatar + name + specialty ──
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.darkBlue500,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initialsFromName(_peerName()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _peerName(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: AppColors.darkBlue900,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _specialty(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.darkBlue500,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Status pill ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(
                  status[0].toUpperCase() + status.substring(1),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Icon(
                  type == 'virtual' ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                  color: AppColors.grey500, size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  type == 'virtual' ? 'Video Consult' : 'In-Person',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.grey500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: scheduledAt != null ? DateFormat('MMMM d, y').format(scheduledAt) : '—',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: scheduledAt != null
                ? '${DateFormat('HH:mm').format(scheduledAt)} – ${DateFormat('HH:mm').format(endAt ?? scheduledAt)}'
                : '—',
          ),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.payments_rounded, label: 'Fee', value: 'XAF ${fee.toInt()}'),

          if (status == 'cancelled' && reason.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Cancellation reason',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.grey500,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.grey200),
              ),
              child: Text(reason, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey700)),
            ),
          ],

          // ── Message tile (patient ↔ doctor chat) ──
          if (canMessage) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _openChat,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.darkBlue500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message ${_peerName()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.darkBlue900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Send a message before or after your visit',
                            style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.grey400),
                  ],
                ),
              ),
            ),
          ],

          // ── CTA buttons ──
          if (canJoin || canCancel) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                if (canCancel)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                if (canCancel && canJoin) const SizedBox(width: 12),
                if (canJoin)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _joinCall,
                      icon: const Icon(Icons.videocam_rounded, size: 18),
                      label: const Text('Join Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBlue500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // ── Provider-only post-call session panel ──
          if (_isProvider) _buildConsultationSessionPanel(a),
        ],
      ),
    );
  }
}

extension _SessionPanel on _AppointmentDetailPageState {
  Widget _buildConsultationSessionPanel(Map<String, dynamic> a) {
    final cid = _consultationId();
    final pid = _patientIdFromAppointment();
    final ended = _sessionEnded;
    final endedAtRaw = _consultation?['ended_at']?.toString();
    final startedAtRaw = _consultation?['started_at']?.toString();

    String formatTimestamp(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt == null) return '';
      return DateFormat('d MMM, HH:mm').format(dt);
    }

    final hasConsultation = cid != null;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: AppColors.darkBlue900,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consultation Session',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ended
                              ? 'Closed · ${formatTimestamp(endedAtRaw)}'
                              : (hasConsultation
                                  ? (startedAtRaw != null && startedAtRaw.isNotEmpty
                                      ? 'In progress · started ${formatTimestamp(startedAtRaw)}'
                                      : 'Awaiting follow-up')
                                  : 'No active consultation yet'),
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SessionStatusPill(active: !ended && hasConsultation, ended: ended),
                ],
              ),
            ),
            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!ended) ...[
                    Text(
                      'Follow-up actions',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.darkBlue900,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ProviderActionTile(
                            icon: Icons.description_rounded,
                            label: 'Write Report',
                            sub: 'Save to record',
                            onTap: () {
                              if (pid == null) {
                                _missingPatient();
                                return;
                              }
                              context.push(
                                '/provider/medical-record/new',
                                extra: {'patientId': pid, 'consultationId': cid},
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ProviderActionTile(
                            icon: Icons.medication_rounded,
                            label: 'Prescribe',
                            sub: 'Issue medication',
                            onTap: () => context.push(
                              '/provider/prescription/new',
                              extra: {'patientId': pid, 'consultationId': cid},
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ProviderActionTile(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Refer',
                            sub: 'Specialist / lab',
                            onTap: () {
                              if (pid == null) {
                                _missingPatient();
                                return;
                              }
                              context.push(
                                '/provider/refer',
                                extra: {'patientId': pid},
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFC2410C), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hanging up the call doesn\u2019t end the session. '
                              'Complete your follow-up first, then end the session below.',
                              style: AppTextStyles.caption.copyWith(
                                color: const Color(0xFF9A3412),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _endingSession || !hasConsultation ? null : _endSession,
                        icon: Icon(
                          _endingSession ? Icons.hourglass_top_rounded : Icons.flag_circle_rounded,
                          size: 18,
                        ),
                        label: Text(_endingSession ? 'Ending…' : 'End Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkBlue800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.accentGreen, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Session closed',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: const Color(0xFF065F46),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Closed at ${formatTimestamp(endedAtRaw)}.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _missingPatient() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Missing patient on this appointment.')),
    );
  }
}

class _SessionStatusPill extends StatelessWidget {
  final bool active;
  final bool ended;
  const _SessionStatusPill({required this.active, required this.ended});

  @override
  Widget build(BuildContext context) {
    final label = ended ? 'Ended' : (active ? 'Active' : 'Pending');
    final dotColor = ended
        ? Colors.white.withValues(alpha: 0.6)
        : (active ? AppColors.accentGreen : const Color(0xFFFBBF24));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _ProviderActionTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.darkBlue900,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.darkBlue900,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.grey500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.grey200)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkBlue500, size: 18),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey700)),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.darkBlue900,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
