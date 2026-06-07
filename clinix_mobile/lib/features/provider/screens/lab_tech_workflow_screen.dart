import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/api_constants.dart';

class LabTechWorkflowScreen extends StatefulWidget {
  const LabTechWorkflowScreen({super.key});

  @override
  State<LabTechWorkflowScreen> createState() => _LabTechWorkflowScreenState();
}

class _LabTechWorkflowScreenState extends State<LabTechWorkflowScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await AuthService.getAccessToken();
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.appointments}lab-tests/',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      if (mounted) {
        setState(() {
          _bookings = (data is List ? data : [])
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load lab test bookings.'; _loading = false; });
    }
  }

  Future<void> _updateStatus(String apptId, String labStatus, {String? results, String? resultsFileUrl}) async {
    try {
      final token = await AuthService.getAccessToken();
      await Dio().patch(
        '${ApiConstants.baseUrl}${ApiConstants.appointments}lab-tests/$apptId/',
        data: {
          'lab_test_status': labStatus,
          if (results != null) 'lab_results': results,
          if (resultsFileUrl != null) 'lab_results_file_url': resultsFileUrl,
        },
        options: Options(headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_statusLabel(labStatus)), backgroundColor: AppColors.accentGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update status'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'accepted': return 'Booking accepted';
      case 'ongoing': return 'Marked as ongoing';
      case 'results_ready': return 'Results posted';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkBlue900, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Lab Test Bookings', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.darkBlue500),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.darkBlue500))
          : _error != null
              ? Center(child: Text(_error!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)))
              : _bookings.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppColors.darkBlue500,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: _bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _LabBookingCard(
                          booking: _bookings[i],
                          onUpdateStatus: _updateStatus,
                        ),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.biotech_outlined, color: AppColors.grey400, size: 34),
          ),
          const SizedBox(height: 16),
          Text('No lab test bookings', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
          const SizedBox(height: 4),
          Text('Bookings from patients will appear here', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
        ],
      ),
    );
  }
}

class _LabBookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Future<void> Function(String, String, {String? results, String? resultsFileUrl}) onUpdateStatus;

  const _LabBookingCard({required this.booking, required this.onUpdateStatus});

  @override
  State<_LabBookingCard> createState() => _LabBookingCardState();
}

class _LabBookingCardState extends State<_LabBookingCard> {
  bool _posting = false;

  String _patientName() {
    final p = widget.booking['patient'];
    if (p is Map) return p['user']?['full_name']?.toString() ?? p['full_name']?.toString() ?? 'Patient';
    return 'Patient';
  }

  String _fmt(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy · HH:mm').format(dt);
  }

  String _labStatusLabel(String? s) {
    switch (s) {
      case 'accepted': return 'Accepted';
      case 'ongoing': return 'Ongoing';
      case 'results_ready': return 'Results Ready';
      default: return 'Pending';
    }
  }

  Color _labStatusColor(String? s) {
    switch (s) {
      case 'accepted': return AppColors.darkBlue500;
      case 'ongoing': return AppColors.accentOrange;
      case 'results_ready': return AppColors.accentGreen;
      default: return AppColors.grey400;
    }
  }

  void _showPostResultsModal() {
    final resultsCtrl = TextEditingController(text: widget.booking['lab_results']?.toString() ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          bool saving = false;
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Post Lab Results', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text('Patient: ${_patientName()} · ${widget.booking['service_name'] ?? ''}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
                const SizedBox(height: 16),
                TextField(
                  controller: resultsCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Enter lab results, findings, or notes...',
                    filled: true,
                    fillColor: AppColors.grey50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setModal(() => saving = true);
                            await widget.onUpdateStatus(
                              widget.booking['appointment_id']?.toString() ?? '',
                              'results_ready',
                              results: resultsCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkBlue500,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Results', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final apptId = b['appointment_id']?.toString() ?? '';
    final serviceName = b['service_name']?.toString() ?? 'Lab Test';
    final address = b['address']?.toString() ?? '';
    final labStatus = b['lab_test_status']?.toString();
    final appointmentStatus = b['status']?.toString() ?? 'pending';
    final hasResults = (b['lab_results']?.toString() ?? '').isNotEmpty;
    final name = _patientName();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.darkBlue500, shape: BoxShape.circle),
                child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkBlue900, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.biotech_rounded, size: 12, color: AppColors.grey400),
                        const SizedBox(width: 4),
                        Flexible(child: Text(serviceName, style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _labStatusColor(labStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _labStatusLabel(labStatus),
                  style: TextStyle(color: _labStatusColor(labStatus), fontWeight: FontWeight.w800, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.grey400),
              const SizedBox(width: 5),
              Text(_fmt(b['scheduled_at']?.toString()), style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 12)),
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 13, color: AppColors.grey400),
                const SizedBox(width: 5),
                Flexible(child: Text(address, style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
          if (hasResults) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.grey50, borderRadius: BorderRadius.circular(10)),
              child: Text(b['lab_results']?.toString() ?? '', style: AppTextStyles.caption.copyWith(color: AppColors.darkBlue900, fontSize: 12, height: 1.5)),
            ),
          ],
          // Workflow actions
          if (appointmentStatus != 'completed' && appointmentStatus != 'cancelled') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.grey100),
            const SizedBox(height: 12),
            _buildActions(apptId, labStatus),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(String apptId, String? labStatus) {
    if (labStatus == null || labStatus.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
          label: const Text('Accept Booking', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkBlue500,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          onPressed: _posting ? null : () => widget.onUpdateStatus(apptId, 'accepted'),
        ),
      );
    }

    if (labStatus == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.science_outlined, size: 16),
          label: const Text('Mark as Ongoing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          onPressed: _posting ? null : () => widget.onUpdateStatus(apptId, 'ongoing'),
        ),
      );
    }

    if (labStatus == 'ongoing') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload_file_rounded, size: 16),
          label: const Text('Post Results', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          onPressed: _showPostResultsModal,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
