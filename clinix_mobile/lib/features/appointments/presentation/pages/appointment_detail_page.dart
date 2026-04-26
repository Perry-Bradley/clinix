import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/appointment_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../screens/video_consultation_screen.dart';

class AppointmentDetailPage extends StatefulWidget {
  final String appointmentId;
  const AppointmentDetailPage({super.key, required this.appointmentId});

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  Map<String, dynamic>? _appointment;
  bool _loading = true;
  bool _isProvider = false;
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

  Future<void> _load() async {
    try {
      final a = await AppointmentService.getAppointment(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _appointment = a;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load appointment.'; _loading = false; });
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

  String? _patientUserId() {
    final p = (_appointment ?? {})['patient'];
    if (p is String) return p;
    if (p is Map) {
      final id = p['user']?['user_id'] ?? p['patient_id'] ?? p['id'];
      if (id != null) return id.toString();
    }
    return null;
  }

  String _patientName() {
    final p = (_appointment ?? {})['patient'];
    if (p is Map) {
      return p['user']?['full_name']?.toString() ?? p['full_name']?.toString() ?? 'Patient';
    }
    return 'Patient';
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
    // Doctor chats with the patient; patient chats with the provider.
    final peerId = _isProvider ? _patientUserId() : _providerId();
    final peerName = _isProvider ? _patientName() : _peerName();
    if (peerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify the other person for chat.')),
      );
      return;
    }
    context.push('/dchat/launch/$peerId?name=${Uri.encodeComponent(peerName)}');
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
    final isLabTest = type == 'lab_test';
    final isHomeTreatment = type == 'home_treatment';
    final isService = isLabTest || isHomeTreatment;
    final scheduledAtStr = a['scheduled_at']?.toString();
    final scheduledAt = scheduledAtStr != null ? DateTime.tryParse(scheduledAtStr)?.toLocal() : null;
    final duration = a['duration_minutes'] ?? 30;
    final endAt = scheduledAt?.add(Duration(minutes: duration is int ? duration : 30));
    final reason = (a['cancellation_reason'] ?? '').toString();
    final feeRaw = (a['provider'] is Map) ? a['provider']['consultation_fee'] : null;
    final fee = double.tryParse(feeRaw?.toString() ?? '') ?? 0;
    final address = a['address']?.toString() ?? '';
    final serviceName = a['service_name']?.toString() ?? '';

    final canJoin = (status == 'confirmed' || status == 'pending') && type == 'virtual';
    // Cancellation is patient-side only; the doctor doesn't cancel from this view.
    final canCancel = !_isProvider && (status == 'pending' || status == 'confirmed');
    // Both sides can open the chat once the appointment is live.
    final canMessage = status != 'cancelled';

    String typeLabel() {
      if (isLabTest) return 'Lab Test';
      if (isHomeTreatment) return 'Home Treatment';
      return type == 'virtual' ? 'Video Consult' : 'In-Person';
    }

    IconData typeIcon() {
      if (isLabTest) return Icons.biotech_rounded;
      if (isHomeTreatment) return Icons.home_filled;
      return type == 'virtual' ? Icons.videocam_rounded : Icons.local_hospital_rounded;
    }

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
                Icon(typeIcon(), color: AppColors.grey500, size: 16),
                const SizedBox(width: 6),
                Text(
                  typeLabel(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.grey500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (isService && serviceName.isNotEmpty) ...[
            _InfoRow(
              icon: isLabTest ? Icons.biotech_rounded : Icons.healing_rounded,
              label: 'Service',
              value: serviceName,
            ),
            const SizedBox(height: 10),
          ],
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
          if (isService && address.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.location_on_rounded, label: 'Address', value: address),
          ],
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
                            'Message ${_isProvider ? _patientName() : _peerName()}',
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

        ],
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
