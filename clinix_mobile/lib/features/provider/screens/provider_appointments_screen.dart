import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/services/appointment_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../shared/widgets/swipe_to_delete.dart';

class ProviderAppointmentsScreen extends StatefulWidget {
  const ProviderAppointmentsScreen({super.key});

  @override
  State<ProviderAppointmentsScreen> createState() =>
      _ProviderAppointmentsScreenState();
}

class _ProviderAppointmentsScreenState
    extends State<ProviderAppointmentsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _all = [];
  Map<DateTime, List<Map<String, dynamic>>> _byDay = {};

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AppointmentService.getMyAppointments();
      final map = <DateTime, List<Map<String, dynamic>>>{};
      for (final a in list) {
        final raw = a['scheduled_at']?.toString();
        if (raw == null) continue;
        final dt = DateTime.tryParse(raw)?.toLocal();
        if (dt == null) continue;
        final key = _dateOnly(dt);
        map.putIfAbsent(key, () => []).add(a);
      }
      for (final v in map.values) {
        v.sort((a, b) {
          final da = DateTime.tryParse(a['scheduled_at']?.toString() ?? '') ??
              DateTime.now();
          final db = DateTime.tryParse(b['scheduled_at']?.toString() ?? '') ??
              DateTime.now();
          return da.compareTo(db);
        });
      }
      if (mounted) {
        setState(() {
          _all = list;
          _byDay = map;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _all = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _eventsForDay(DateTime day) =>
      _byDay[_dateOnly(day)] ?? const [];

  int get _todayCount =>
      _eventsForDay(DateTime.now()).where((a) {
        final s = a['status']?.toString();
        return s != 'cancelled';
      }).length;

  int get _upcomingCount {
    final now = DateTime.now();
    return _all.where((a) {
      final dt =
          DateTime.tryParse(a['scheduled_at']?.toString() ?? '')?.toLocal();
      if (dt == null) return false;
      return dt.isAfter(now) && a['status'] != 'cancelled';
    }).length;
  }

  Future<void> _cancel(String apptId) async {
    try {
      await AppointmentService.cancelAppointment(apptId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment cancelled'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not cancel appointment'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _eventsForDay(_selectedDay);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Appointments',
          style: AppTextStyles.headlineMedium.copyWith(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.darkBlue900,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.today_rounded,
              color: AppColors.darkBlue500,
              size: 22,
            ),
            tooltip: 'Jump to today',
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = _dateOnly(DateTime.now());
              });
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.darkBlue500),
            )
          : RefreshIndicator(
              color: AppColors.darkBlue500,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildSummary()),
                  SliverToBoxAdapter(child: _buildCalendar()),
                  SliverToBoxAdapter(child: _buildSectionHeader(selected.length)),
                  if (selected.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _AppointmentCard(
                            appointment: selected[i],
                            onCancel: _cancel,
                          ),
                          childCount: selected.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.today_rounded,
              label: 'Today',
              value: '$_todayCount',
              accent: AppColors.darkBlue500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.schedule_rounded,
              label: 'Upcoming',
              value: '$_upcomingCount',
              accent: AppColors.accentCyan,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.event_note_rounded,
              label: 'Total',
              value: '${_all.length}',
              accent: AppColors.accentGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.grey200),
      ),
      child: TableCalendar<Map<String, dynamic>>(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
        eventLoader: _eventsForDay,
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Month',
          CalendarFormat.twoWeeks: '2 Weeks',
          CalendarFormat.week: 'Week',
        },
        onDaySelected: (sel, foc) {
          setState(() {
            _selectedDay = _dateOnly(sel);
            _focusedDay = foc;
          });
        },
        onFormatChanged: (f) => setState(() => _calendarFormat = f),
        onPageChanged: (foc) => _focusedDay = foc,
        headerStyle: HeaderStyle(
          formatButtonShowsNext: false,
          titleCentered: true,
          titleTextStyle: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.darkBlue900,
            fontSize: 15,
          ),
          formatButtonDecoration: BoxDecoration(
            color: AppColors.darkBlue500.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          formatButtonTextStyle: const TextStyle(
            color: AppColors.darkBlue500,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          formatButtonPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leftChevronIcon: const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.darkBlue500,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.darkBlue500,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.grey500,
          ),
          weekendStyle: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.darkBlue500,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
            color: AppColors.darkBlue500.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.darkBlue500,
            fontWeight: FontWeight.w800,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.darkBlue500,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          defaultTextStyle: const TextStyle(
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w600,
          ),
          weekendTextStyle: const TextStyle(
            color: AppColors.darkBlue900,
            fontWeight: FontWeight.w600,
          ),
          markerDecoration: const BoxDecoration(
            color: AppColors.accentOrange,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          markerSize: 5,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(int count) {
    final label = _formatHeaderDate(_selectedDay);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue900,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.darkBlue500.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count == 1 ? '1 appointment' : '$count appointments',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.darkBlue500,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: AppColors.grey400,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No appointments',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.darkBlue900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You have no appointments on this day',
              style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHeaderDate(DateTime d) {
    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today) return 'Today';
    if (d == tomorrow) return 'Tomorrow';
    if (d == yesterday) return 'Yesterday';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]}';
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue900,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.grey500,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Future<void> Function(String) onCancel;
  const _AppointmentCard({required this.appointment, required this.onCancel});

  String _patientName() {
    final p = appointment['patient'];
    if (p is Map) {
      return p['user']?['full_name']?.toString() ??
          p['full_name']?.toString() ??
          'Patient';
    }
    return 'Patient';
  }

  String _initials(String fullName) {
    final cleaned = fullName
        .replaceAll(
          RegExp(r'^(Dr\.?|Doctor|Mr\.?|Mrs\.?|Ms\.?)\s+',
              caseSensitive: false),
          '',
        )
        .trim();
    if (cleaned.isEmpty) return '?';
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final status = appointment['status']?.toString() ?? 'pending';
    final type = appointment['appointment_type']?.toString() ?? 'virtual';
    final isVideo = type == 'virtual';
    final isLab = type == 'lab_test';
    final isHome = type == 'home_treatment';
    final dt = DateTime.tryParse(appointment['scheduled_at']?.toString() ?? '')
        ?.toLocal();
    final time = dt != null
        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '--:--';
    final apptId = appointment['appointment_id']?.toString() ?? '';
    final name = _patientName();
    final canCancel = status == 'pending' || status == 'confirmed';

    Color statusColor;
    switch (status) {
      case 'pending':
        statusColor = AppColors.accentOrange;
        break;
      case 'confirmed':
        statusColor = AppColors.accentGreen;
        break;
      case 'completed':
        statusColor = AppColors.grey500;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.grey500;
    }

    String typeLabel() {
      if (isLab) return 'Lab Test';
      if (isHome) return 'Home Treatment';
      return isVideo ? 'Video' : 'In-Person';
    }

    IconData typeIcon() {
      if (isLab) return Icons.biotech_rounded;
      if (isHome) return Icons.home_filled;
      return isVideo ? Icons.videocam_rounded : Icons.local_hospital_rounded;
    }

    final card = GestureDetector(
      onTap: apptId.isEmpty
          ? null
          : () => context.push('/appointments/$apptId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.darkBlue500.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    time,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkBlue500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(typeIcon(), size: 14, color: AppColors.darkBlue500),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.darkBlue500,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkBlue900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    typeLabel(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.grey500,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!canCancel || apptId.isEmpty) return card;
    return SwipeToDeleteCard(
      dismissibleKey: 'pappt-$apptId',
      deleteLabel: 'Cancel',
      confirmTitle: 'Cancel appointment?',
      confirmBody: 'The patient will be notified.',
      deletedSnack: 'Appointment cancelled',
      onDelete: () async {
        await onCancel(apptId);
        return true;
      },
      child: card,
    );
  }
}
