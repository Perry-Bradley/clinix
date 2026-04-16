import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/auth_service.dart';
import '../../../shared/widgets/custom_sidebar_drawer.dart';
import '../../../shared/widgets/bubble_bottom_bar.dart';
import '../../screens/doctors_list_screen.dart';
import '../../screens/nearby_clinics_screen.dart';
import '../../screens/health_dashboard_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/health_metric_service.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/appointment_service.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  int _selectedTab = 0;

  final List<Widget> _pages = const [
    _PatientDashboard(),
    DoctorsListScreen(),
    NearbyClinicsScreen(),
    HealthDashboardScreen(),
    _PatientProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      drawer: CustomSidebarDrawer(
        currentIndex: _selectedTab,
        onTabSelected: (i) => setState(() => _selectedTab = i),
        isProvider: false,
      ),
      body: IndexedStack(index: _selectedTab, children: _pages),
      bottomNavigationBar: BubbleBottomBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        items: [
          BubbleNavItem(icon: Icons.home_outlined, label: 'Home'),
          BubbleNavItem(icon: Icons.search_rounded, label: 'Doctors'),
          BubbleNavItem(icon: Icons.map_outlined, label: 'Map'),
          BubbleNavItem(icon: Icons.favorite_outline_rounded, label: 'Health'),
          BubbleNavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}

class _PatientDashboard extends StatefulWidget {
  const _PatientDashboard();

  @override
  State<_PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<_PatientDashboard> {
  String _userName = 'User';
  String _greeting = 'Good Day';
  IconData _greetingIcon = Icons.wb_sunny_rounded;
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await AuthService.getUserName();
    final hour = DateTime.now().hour;
    
    String greeting;
    IconData icon;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good Morning';
      icon = Icons.wb_twilight_rounded;
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
      icon = Icons.wb_sunny_rounded;
    } else {
      greeting = 'Good Evening';
      icon = Icons.nightlight_round;
    }

    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _userName = name;
        _greeting = greeting;
        _greetingIcon = icon;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          toolbarHeight: 230,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 58, 24, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(_greeting, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.sky200)),
                              const SizedBox(width: 6),
                              Icon(_greetingIcon, size: 13, color: AppColors.sky200),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Center(child: Icon(Icons.notifications_none_rounded, color: AppColors.white, size: 22)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                GestureDetector(
                  onTap: () {
                    final state = context.findAncestorStateOfType<_PatientHomePageState>();
                    state?.setState(() => state._selectedTab = 1);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppColors.sky200, size: 20),
                        const SizedBox(width: 12),
                        Text('Find doctors, medicines...', style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.sky200.withValues(alpha: 0.75))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Feature Grid (2x2)
              Row(
                children: [
                  Expanded(child: _buildFeatureCard(icon: Icons.spa_rounded, color: AppColors.sky500, title: 'Clinix AI', subtitle: 'Health Assistant', onTap: () => context.push('/ai-consult'))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFeatureCard(icon: Icons.person_search_rounded, color: AppColors.accentCyan, title: 'Consult', subtitle: 'Find a Doctor', onTap: () {
                    final state = context.findAncestorStateOfType<_PatientHomePageState>();
                    state?.setState(() => state._selectedTab = 1);
                  })),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildFeatureCard(icon: Icons.home_repair_service_rounded, color: AppColors.accentOrange, title: 'HomeCare', subtitle: 'Care at Home', onTap: () {})),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFeatureCard(icon: Icons.monitor_heart_rounded, color: AppColors.accentGreen, title: 'Health', subtitle: 'Track Vitals', onTap: () {
                    final state = context.findAncestorStateOfType<_PatientHomePageState>();
                    state?.setState(() => state._selectedTab = 3);
                  })),
                ],
              ),
              const SizedBox(height: 24),
              // Health Overview Card
              Consumer(
                builder: (context, ref, child) {
                  final summaryAsync = ref.watch(healthSummaryProvider);
                  return _AnimatedHealthCard(summaryAsync: summaryAsync);
                },
              ),
              const SizedBox(height: 28),
              // Upcoming Appointments
              _UpcomingAppointments(),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.darkBlue900)),
                  Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.grey400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHealthCard extends StatefulWidget {
  final AsyncValue<Map<String, dynamic>> summaryAsync;
  const _AnimatedHealthCard({required this.summaryAsync});

  @override
  State<_AnimatedHealthCard> createState() => _AnimatedHealthCardState();
}

class _AnimatedHealthCardState extends State<_AnimatedHealthCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideUp,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.grey200),
            boxShadow: [BoxShadow(color: AppColors.sky500.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.sky100, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.monitor_heart_rounded, color: AppColors.sky500, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Health Overview', style: AppTextStyles.headlineSmall.copyWith(fontSize: 15)),
                  const Spacer(),
                  widget.summaryAsync.when(
                    data: (data) {
                      final lastDate = data['latest_heart_rate']?['measured_at'];
                      if (lastDate == null) return const SizedBox();
                      return Text('${DateFormat('HH:mm').format(DateTime.parse(lastDate))}', style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 10));
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              widget.summaryAsync.when(
                data: (data) => Row(
                  children: [
                    _HealthMini(icon: Icons.favorite_rounded, label: 'Heart Rate', value: data['latest_heart_rate'] != null ? '${data['latest_heart_rate']['bpm']}' : '--', unit: 'bpm', color: const Color(0xFFEF4444)),
                    const SizedBox(width: 12),
                    _HealthMini(icon: Icons.directions_walk_rounded, label: 'Steps', value: '${data['today_activity']?['steps'] ?? 0}', unit: 'today', color: AppColors.sky500),
                    const SizedBox(width: 12),
                    _HealthMini(icon: Icons.air_rounded, label: 'Resp.', value: data['latest_heart_rate']?['respiratory_rate']?.toString() ?? '--', unit: 'bpm', color: AppColors.accentGreen),
                  ],
                ),
                loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sky500))),
                error: (_, __) => Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: AppColors.grey400, size: 16),
                    const SizedBox(width: 8),
                    Text('Could not load vitals', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _HealthMini({required this.icon, required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkBlue900, fontFamily: 'Inter')),
            Text(unit, style: AppTextStyles.caption.copyWith(color: AppColors.grey400, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _UpcomingAppointments extends StatefulWidget {
  const _UpcomingAppointments();
  @override
  State<_UpcomingAppointments> createState() => _UpcomingAppointmentsState();
}

class _UpcomingAppointmentsState extends State<_UpcomingAppointments> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final all = await AppointmentService.getMyAppointments();
      final now = DateTime.now();
      final upcoming = all.where((a) {
        final status = a['status']?.toString() ?? '';
        if (status != 'pending' && status != 'confirmed') return false;
        final dateStr = a['scheduled_at']?.toString();
        if (dateStr == null) return false;
        final date = DateTime.tryParse(dateStr);
        return date != null && date.isAfter(now);
      }).take(3).toList();
      if (mounted) setState(() { _appointments = upcoming; _isLoading = false; });
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox();
    if (_appointments.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Upcoming Appointments', style: AppTextStyles.headlineMedium.copyWith(fontSize: 18)),
            GestureDetector(
              onTap: () => context.push('/patient/appointments'),
              child: Text('See All', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._appointments.map((a) {
          final providerName = a['provider_name']?.toString() ?? a['provider']?['full_name']?.toString() ?? 'Doctor';
          final dateStr = a['scheduled_at']?.toString() ?? '';
          final date = DateTime.tryParse(dateStr);
          final formattedDate = date != null ? DateFormat('EEE, MMM d').format(date.toLocal()) : '';
          final formattedTime = date != null ? DateFormat('HH:mm').format(date.toLocal()) : '';
          final status = a['status']?.toString() ?? 'pending';
          final type = a['appointment_type']?.toString() ?? 'virtual';
          final isPending = status == 'pending';

          return GestureDetector(
            onTap: () => context.push('/appointments/${a['appointment_id']}'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPending ? AppColors.darkBlue500.withValues(alpha: 0.2) : AppColors.sky200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: (isPending ? AppColors.darkBlue600 : AppColors.sky500).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      type == 'virtual' ? Icons.video_call_rounded : Icons.local_hospital_rounded,
                      color: isPending ? AppColors.darkBlue600 : AppColors.sky500,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(providerName, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('$formattedDate at $formattedTime', style: AppTextStyles.caption.copyWith(color: AppColors.grey500, fontSize: 12)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPending ? AppColors.darkBlue600 : AppColors.accentGreen).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPending ? 'Pending' : 'Confirmed',
                      style: AppTextStyles.caption.copyWith(
                        color: isPending ? AppColors.darkBlue600 : AppColors.accentGreen,
                        fontWeight: FontWeight.w700, fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PatientDoctorsTab extends StatelessWidget {
  const _PatientDoctorsTab();

  static const List<Map<String, String>> _mockDoctors = [
    {'name': 'Dr. Marie Nkomo', 'spec': 'Cardiologist', 'rating': '4.9', 'id': '1'},
    {'name': 'Dr. Jean Paul', 'spec': 'Neurologist', 'rating': '4.8', 'id': '2'},
    {'name': 'Dr. Sarah Smith', 'spec': 'Pediatrician', 'rating': '4.7', 'id': '3'},
    {'name': 'Dr. Robert King', 'spec': 'Dermatologist', 'rating': '4.9', 'id': '4'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.darkBlue900,
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('Find Doctors', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white, fontSize: 16)),
              background: Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _DoctorListTile(doctor: _mockDoctors[i % _mockDoctors.length]),
                childCount: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorListTile extends StatelessWidget {
  final Map<String, String> doctor;
  const _DoctorListTile({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [BoxShadow(color: AppColors.darkBlue900.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.darkBlue700, AppColors.sky500]), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor['name']!, style: AppTextStyles.headlineSmall),
                const SizedBox(height: 2),
                Text(doctor['spec']!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 14),
                    const SizedBox(width: 4),
                    Text(doctor['rating']!, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    const Icon(Icons.circle, color: AppColors.accentGreen, size: 8),
                    const SizedBox(width: 4),
                    Text('Available', style: AppTextStyles.caption.copyWith(color: AppColors.accentGreen)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/appointments/book?providerId=mock'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.sky600, AppColors.sky400]), borderRadius: BorderRadius.circular(12)),
              child: Text('Book', style: AppTextStyles.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => context.push('/chat/mock_chat_${doctor['id']}?doctorName=${Uri.encodeComponent(doctor['name']!)}'),
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.sky500),
          ),
        ],
      ),
    );
  }
}

class _PatientAppointmentsTab extends StatelessWidget {
  const _PatientAppointmentsTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.darkBlue900,
          pinned: true,
          title: Text('My Appointments', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.white, fontSize: 16)),
          automaticallyImplyLeading: false,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Row(
                  children: [
                    Container(width: 4, height: 60, decoration: BoxDecoration(color: i % 2 == 0 ? AppColors.sky500 : AppColors.accentGreen, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i % 2 == 0 ? 'Dr. Jean Paul' : 'Dr. Marie Nkomo', style: AppTextStyles.headlineSmall.copyWith(fontSize: 15)),
                          Text(i % 2 == 0 ? 'Neurology' : 'Cardiology', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky500)),
                          const SizedBox(height: 6),
                          Text(i % 2 == 0 ? 'Apr 12, 2026 • 09:30 AM' : 'Apr 08, 2026 • 14:00 PM', style: AppTextStyles.caption.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: i % 2 == 0 ? AppColors.sky100 : AppColors.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            i % 2 == 0 ? 'Confirmed' : 'Completed',
                            style: AppTextStyles.caption.copyWith(color: i % 2 == 0 ? AppColors.sky600 : AppColors.accentGreen, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (i % 2 != 0) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showRatingPrompt(context, 'Dr. Marie Nkomo'),
                            child: Text('Rate Visit', style: TextStyle(color: AppColors.sky600, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}

class _PatientProfileTab extends StatefulWidget {
  const _PatientProfileTab();

  @override
  State<_PatientProfileTab> createState() => _PatientProfileTabState();
}

class _PatientProfileTabState extends State<_PatientProfileTab> {
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await AuthService.getUserName();
    if (mounted && name != null) setState(() => _userName = name);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
            ),
            child: Column(
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  ),
                  child: const Center(child: Icon(Icons.person_rounded, color: AppColors.white, size: 50)),
                ),
                const SizedBox(height: 18),
                Text(_userName, style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white, fontSize: 24)),
                const SizedBox(height: 4),
                Text('Verified Patient', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sky200, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ProfileMenuItem(icon: Icons.medical_information_rounded, label: 'Medical Records', onTap: () => context.push('/patient/medical-records')),
              _ProfileMenuItem(icon: Icons.receipt_long_rounded, label: 'Prescriptions', onTap: () => context.push('/patient/prescriptions')),
              _ProfileMenuItem(icon: Icons.payment_rounded, label: 'Payment History', onTap: () => context.push('/patient/payment-history')),
              _ProfileMenuItem(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => context.push('/notifications')),
              _ProfileMenuItem(icon: Icons.info_outline_rounded, label: 'About Clinix', onTap: () => context.push('/about')),
              const SizedBox(height: 12),
              _ProfileMenuItem(
                icon: Icons.logout_rounded, 
                label: 'Log Out', 
                color: AppColors.error, 
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log Out'),
                      content: const Text('Are you sure you want to log out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await AuthService.logout();
                    if (context.mounted) context.go('/login');
                  }
                }
              ),
              const SizedBox(height: 100), // Space for bottom bar
            ]),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ProfileMenuItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.darkBlue800;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(label, style: AppTextStyles.headlineSmall.copyWith(fontSize: 14, color: c)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.grey400, size: 20),
      ),
    );
  }
}

void _showRatingPrompt(BuildContext context, String doctorName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RatingModal(doctorName: doctorName),
  );
}

class _RatingModal extends StatefulWidget {
  final String doctorName;
  const _RatingModal({super.key, required this.doctorName});
  @override
  State<_RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends State<_RatingModal> {
  int _rating = 0;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text('How was your visit with ${widget.doctorName}?', textAlign: TextAlign.center, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          Text('Your feedback helps us improve our healthcare services.', textAlign: TextAlign.center, style: AppTextStyles.caption),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
              icon: Icon(Icons.star_rounded, size: 44, color: i < _rating ? const Color(0xFFFBBF24) : AppColors.grey200),
              onPressed: () => setState(() => _rating = i + 1),
            )),
          ),
          const SizedBox(height: 24),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any specific feedback? (Optional)',
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.sky500)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: AppColors.accentGreen),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sky600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Submit Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
