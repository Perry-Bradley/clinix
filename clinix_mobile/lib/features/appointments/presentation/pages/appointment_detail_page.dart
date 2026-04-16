import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/appointment_service.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await AppointmentService.getAppointment(widget.appointmentId);
      if (mounted) setState(() { _appointment = a; _loading = false; });
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
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel'), backgroundColor: Colors.redAccent));
      }
    }
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
      case 'confirmed': return AppColors.sky500;
      case 'completed': return AppColors.accentGreen;
      case 'cancelled': return AppColors.error;
      case 'no_show': return AppColors.grey500;
      default: return AppColors.accentOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.sky500)));
    }
    if (_error != null || _appointment == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20), onPressed: () => context.pop()),
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

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.darkBlue900,
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.white, size: 16),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(Icons.person_rounded, color: AppColors.white, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_peerName(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text(_specialty(), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Status Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _statusColor(status).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(status[0].toUpperCase() + status.substring(1), style: AppTextStyles.headlineSmall.copyWith(color: _statusColor(status))),
                      const Spacer(),
                      Row(children: [
                        Icon(type == 'virtual' ? Icons.videocam_rounded : Icons.local_hospital_rounded, color: _statusColor(status), size: 18),
                        const SizedBox(width: 6),
                        Text(type == 'virtual' ? 'Video Consult' : 'In-Person', style: AppTextStyles.bodyMedium.copyWith(color: _statusColor(status))),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _InfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: scheduledAt != null ? DateFormat('MMMM d, y').format(scheduledAt) : '—',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: scheduledAt != null
                      ? '${DateFormat('HH:mm').format(scheduledAt)} - ${DateFormat('HH:mm').format(endAt ?? scheduledAt)}'
                      : '—',
                ),
                const SizedBox(height: 12),
                _InfoRow(icon: Icons.attach_money_rounded, label: 'Fee', value: 'XAF ${fee.toInt()}'),
                const SizedBox(height: 28),

                if (status == 'cancelled' && reason.isNotEmpty) ...[
                  Text('Cancellation Reason', style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.grey200)),
                    child: Text(reason, style: AppTextStyles.bodyLarge),
                  ),
                  const SizedBox(height: 28),
                ],

                // CTA Buttons
                if (canJoin || canCancel)
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
                              backgroundColor: AppColors.sky500,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                    ],
                  ),
              ]),
            ),
          ),
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
          Icon(icon, color: AppColors.sky500, size: 20),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMedium),
          const Spacer(),
          Text(value, style: AppTextStyles.headlineSmall.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}
